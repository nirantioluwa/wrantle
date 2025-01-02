import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["number"]
  static values = {
    finalNumber: Number,
    prefix: String,
    suffix: String
  }

  connect() {
    this.animate()
  }

  animate() {
    const finalNumber = this.finalNumberValue
    const stepDuration = 2400 // 1.2 seconds per operation
    const operations = this.generateOperations(finalNumber)
    let currentStep = 0

    const animate = () => {
      if (currentStep < operations.length) {
        const operation = operations[currentStep]
        this.numberTarget.innerHTML = this.formatOperation(operation)
        currentStep++
        setTimeout(animate, stepDuration)
      } else {
        // Add a slight pause before showing final number
        setTimeout(() => {
          this.numberTarget.textContent = `${this.prefixValue || ''}${this.formatNumber(finalNumber)}${this.suffixValue || ''}`
        }, 400)
      }
    }

    animate()
  }

  generateOperations(finalNumber) {
    const operations = []
    
    if (finalNumber >= 1000000) {
      // For millions, show multiplication steps
      const millions = finalNumber / 1000000
      operations.push({ type: 'multiply', nums: [200, 1.5] })
      operations.push({ type: 'multiply', nums: [300, 1000000] })
    } else if (finalNumber > 100) {
      // For numbers > 100, show addition and multiplication
      const base = Math.floor(finalNumber * 0.7)
      const remainder = finalNumber - base
      operations.push({ type: 'multiply', nums: [Math.floor(base/2), 2] })
      operations.push({ type: 'add', nums: [base, remainder] })
    } else {
      // For smaller numbers, show simple arithmetic
      const third = Math.floor(finalNumber / 3)
      operations.push({ type: 'multiply', nums: [third, 2] })
      operations.push({ type: 'add', nums: [third * 2, finalNumber - (third * 2)] })
    }

    return operations
  }

  formatOperation(operation) {
    const prefix = this.prefixValue || ''
    let display = ''

    switch (operation.type) {
      case 'add':
        display = `${this.formatNumber(operation.nums[0])} + ${this.formatNumber(operation.nums[1])}`
        break
      case 'multiply':
        display = `${this.formatNumber(operation.nums[0])} × ${this.formatNumber(operation.nums[1])}`
        break
      case 'subtract':
        display = `${this.formatNumber(operation.nums[0])} - ${this.formatNumber(operation.nums[1])}`
        break
      case 'divide':
        display = `${this.formatNumber(operation.nums[0])} ÷ ${this.formatNumber(operation.nums[1])}`
        break
    }

    return `${prefix}${display}`
  }

  formatNumber(number) {
    // If it's greater than 1 million, show as XM
    if (number >= 1000000) {
      return Math.round(number / 1000000) + 'M'
    }
    
    // If it's greater than 1000, add commas
    if (number >= 1000) {
      return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }
    
    // If it's a decimal, keep one decimal place
    if (number % 1 !== 0) {
      return number.toFixed(1)
    }
    
    return number.toString()
  }
}
