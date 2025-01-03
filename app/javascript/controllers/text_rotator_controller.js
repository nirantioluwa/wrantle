import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]
  static values = {
    items: Array,
    interval: { type: Number, default: 100000 }
  }

  connect() {
    this.currentIndex = 0
    this.isTyping = false
    this.rotate()
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  async typeText(text) {
    this.isTyping = true
    let currentText = ""
    
    for (let i = 0; i < text.length; i++) {
      currentText += text[i]
      this.textTarget.textContent = currentText
      await new Promise(resolve => setTimeout(resolve, 100)) // 50ms per character
    }
    
    this.isTyping = false
  }

  async deleteText() {
    let currentText = this.textTarget.textContent
    
    while (currentText.length > 0) {
      currentText = currentText.slice(0, -1)
      this.textTarget.textContent = currentText
      await new Promise(resolve => setTimeout(resolve, 30)) // 30ms per character deletion
    }
  }

  rotate() {
    this.intervalId = setInterval(async () => {
      if (this.isTyping) return
      
      await this.deleteText()
      
      this.currentIndex = (this.currentIndex + 1) % this.itemsValue.length
      await this.typeText(this.itemsValue[this.currentIndex])
      
    }, this.intervalValue)
  }
}
