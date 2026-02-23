import { Controller } from "@hotwired/stimulus"

const OPENAI_REALTIME_CALLS_URL = "https://api.openai.com/v1/realtime/calls"
const MAX_REPLY_CHARS = 2000

export default class extends Controller {
  static targets = ["form", "body", "submit"]

  static values = {
    messagesContainerId: String,
    currentUsername: String,
    enabled: Boolean,
    sessionPath: String,
    contextLimit: { type: Number, default: 20 }
  }

  connect() {
    this.handledMessageIds = new Set()
    this.inflight = false
    this.messagesContainer = document.getElementById(this.messagesContainerIdValue)
    if (!this.messagesContainer) return

    this.observer = new MutationObserver((mutations) => this.handleMutations(mutations))
    this.observer.observe(this.messagesContainer, { childList: true, subtree: true })
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  handleMutations(mutations) {
    if (!this.enabledValue || this.inflight) return

    for (const mutation of mutations) {
      for (const addedNode of mutation.addedNodes) {
        if (!(addedNode instanceof HTMLElement)) continue

        if (addedNode.matches("[data-chat-message-id]")) {
          this.handleMessageElement(addedNode)
          continue
        }

        const nestedMessages = addedNode.querySelectorAll("[data-chat-message-id]")
        for (const messageElement of nestedMessages) {
          this.handleMessageElement(messageElement)
        }
      }
    }
  }

  handleMessageElement(messageElement) {
    const messageId = messageElement.dataset.chatMessageId
    if (!messageId || this.handledMessageIds.has(messageId)) return

    this.markHandled(messageId)

    const authorUsername = (messageElement.dataset.chatMessageAuthorUsername || "").toLowerCase()
    if (!authorUsername || authorUsername === this.currentUsernameValue.toLowerCase()) return

    const bodyElement = messageElement.querySelector("[data-chat-message-body]")
    const incomingText = bodyElement?.textContent?.trim()
    if (!incomingText || !this.isMentionForCurrentUser(incomingText)) return

    this.generateReply(incomingText, authorUsername)
  }

  async generateReply(incomingText, authorUsername) {
    if (this.inflight || !this.hasBodyTarget || !this.hasFormTarget) return

    this.inflight = true
    this.setComposerBusy(true)
    this.bodyTarget.value = ""
    let closeConnection = null

    try {
      const { client_secret: clientSecret, bot_character: botCharacter } = await this.fetchBotSession()
      const { dataChannel, close } = await this.openRealtimeConnection(clientSecret)
      closeConnection = close

      await this.streamResponseIntoComposer(dataChannel, {
        incomingText,
        authorUsername,
        botCharacter
      })

      this.autoSubmitIfPresent()
    } catch (error) {
      console.error("[chat-bot] generation failed", error)
    } finally {
      if (closeConnection) closeConnection()
      this.setComposerBusy(false)
      this.inflight = false
    }
  }

  async fetchBotSession() {
    const response = await fetch(this.sessionPathValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken
      }
    })

    if (!response.ok) {
      throw new Error(`Failed to fetch bot session (${response.status})`)
    }

    return response.json()
  }

  async openRealtimeConnection(clientSecret) {
    const peerConnection = new RTCPeerConnection()
    // OpenAI Realtime currently expects an audio m-line in the SDP offer.
    peerConnection.addTransceiver("audio", { direction: "recvonly" })

    const dataChannel = peerConnection.createDataChannel("oai-events")
    const offer = await peerConnection.createOffer()

    await peerConnection.setLocalDescription(offer)

    const response = await fetch(OPENAI_REALTIME_CALLS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${clientSecret}`,
        "Content-Type": "application/sdp"
      },
      body: offer.sdp
    })

    if (!response.ok) {
      throw new Error(`Failed to establish realtime call (${response.status})`)
    }

    const sdpAnswer = await response.text()
    if (sdpAnswer.trim().length === 0) {
      throw new Error("Missing realtime SDP answer")
    }

    await peerConnection.setRemoteDescription({
      type: "answer",
      sdp: sdpAnswer
    })

    await this.waitForOpenDataChannel(dataChannel)

    return {
      dataChannel,
      close: () => {
        if (dataChannel.readyState === "open") dataChannel.close()
        peerConnection.close()
      }
    }
  }

  async streamResponseIntoComposer(dataChannel, { incomingText, authorUsername, botCharacter }) {
    const systemPrompt = this.buildSystemPrompt(botCharacter)
    const userPrompt = this.buildUserPrompt(incomingText, authorUsername)

    const completion = new Promise((resolve, reject) => {
      let done = false
      const timeout = setTimeout(() => {
        if (!done) {
          done = true
          reject(new Error("Timed out while waiting for realtime completion"))
        }
      }, 45_000)

      dataChannel.addEventListener("message", (event) => {
        let payload
        try {
          payload = JSON.parse(event.data)
        } catch (_) {
          return
        }

        if (payload.type === "error") {
          if (!done) {
            done = true
            clearTimeout(timeout)
            reject(new Error(payload.error?.message || "Realtime API returned an error"))
          }
          return
        }

        const delta = this.extractTextDelta(payload)
        if (delta) {
          this.appendToComposer(delta)
        }

        if (this.isCompletionEvent(payload.type) && !done) {
          done = true
          clearTimeout(timeout)
          resolve()
        }
      })
    })

    dataChannel.send(JSON.stringify({
      type: "conversation.item.create",
      item: {
        type: "message",
        role: "user",
        content: [ { type: "input_text", text: userPrompt } ]
      }
    }))

    dataChannel.send(JSON.stringify({
      type: "response.create",
      response: {
        instructions: systemPrompt,
        max_output_tokens: 1000,
        output_modalities: [ "text" ]
      }
    }))

    await completion
  }

  buildSystemPrompt(botCharacter) {
    const normalizedCharacter = (botCharacter || "").trim()
    const characterPart = normalizedCharacter.length > 0 ? normalizedCharacter : "You are concise, friendly, and helpful."

    return [
      `You are @${this.currentUsernameValue}'s automatic chat bot.`,
      "Write in German unless the user message clearly uses a different language.",
      "Keep the reply short and useful.",
      `Never exceed ${MAX_REPLY_CHARS} characters.`,
      "Stay fully in character:",
      characterPart
    ].join("\n")
  }

  buildUserPrompt(incomingText, authorUsername) {
    const context = this.recentContext()
    return [
      `Incoming message from @${authorUsername}:`,
      incomingText,
      "",
      "Recent room context:",
      context
    ].join("\n")
  }

  recentContext() {
    if (!this.messagesContainer) return "(none)"

    const rows = Array.from(this.messagesContainer.querySelectorAll("[data-chat-message-id]"))
      .slice(-this.contextLimitValue)
      .map((messageElement) => {
        const author = messageElement.dataset.chatMessageAuthorUsername || "unknown"
        const body = messageElement.querySelector("[data-chat-message-body]")?.textContent?.trim() || ""
        return `@${author}: ${body}`
      })

    return rows.length > 0 ? rows.join("\n") : "(none)"
  }

  isMentionForCurrentUser(text) {
    const escaped = this.currentUsernameValue.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const mentionPattern = new RegExp(`(^|\\s)@${escaped}\\b`, "i")
    return mentionPattern.test(text)
  }

  isCompletionEvent(type) {
    return [ "response.output_text.done", "response.completed", "response.done" ].includes(type)
  }

  extractTextDelta(payload) {
    if (payload.type === "response.output_text.delta" && typeof payload.delta === "string") return payload.delta
    if (payload.type === "response.text.delta" && typeof payload.delta === "string") return payload.delta
    if (payload.type === "response.delta" && typeof payload.delta === "string") return payload.delta
    return null
  }

  appendToComposer(chunk) {
    if (!this.hasBodyTarget || chunk.length === 0) return

    const next = `${this.bodyTarget.value}${chunk}`.slice(0, MAX_REPLY_CHARS)
    this.bodyTarget.value = next
  }

  autoSubmitIfPresent() {
    if (!this.hasFormTarget || !this.hasBodyTarget) return
    if (this.bodyTarget.value.trim().length === 0) return
    this.formTarget.requestSubmit()
  }

  setComposerBusy(isBusy) {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = isBusy
      this.submitTarget.classList.toggle("opacity-60", isBusy)
      this.submitTarget.classList.toggle("cursor-not-allowed", isBusy)
    }

    if (this.hasBodyTarget) {
      this.bodyTarget.readOnly = isBusy
    }
  }

  waitForOpenDataChannel(dataChannel) {
    if (dataChannel.readyState === "open") return Promise.resolve()

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timed out waiting for realtime data channel")), 10_000)

      dataChannel.addEventListener("open", () => {
        clearTimeout(timeout)
        resolve()
      }, { once: true })
    })
  }

  markHandled(messageId) {
    this.handledMessageIds.add(messageId)
    if (this.handledMessageIds.size > 500) {
      this.handledMessageIds = new Set(Array.from(this.handledMessageIds).slice(-250))
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
