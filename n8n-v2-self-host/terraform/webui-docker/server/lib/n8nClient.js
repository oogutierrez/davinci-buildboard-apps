const axios = require('axios')
const https = require('https')

class N8nClient {
  constructor() {
    this.baseURL = (process.env.N8N_API_URL || 'http://localhost:5678').replace(/\/$/, '')
    this.apiKey = process.env.N8N_API_KEY

    this.client = axios.create({
      baseURL: `${this.baseURL}/api/v1`,
      headers: {
        'X-N8N-API-KEY': this.apiKey,
        'Content-Type': 'application/json'
      },
      httpsAgent: new https.Agent({ rejectUnauthorized: false })
    })
  }

  // Workflows
  async getWorkflows() {
    try {
      const response = await this.client.get('/workflows')
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async getWorkflow(id) {
    try {
      const response = await this.client.get(`/workflows/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async activateWorkflow(id) {
    try {
      const response = await this.client.post(`/workflows/${id}/activate`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async deactivateWorkflow(id) {
    try {
      const response = await this.client.post(`/workflows/${id}/deactivate`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async deleteWorkflow(id) {
    try {
      const response = await this.client.delete(`/workflows/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  // Executions
  async getExecutions(params = {}) {
    try {
      const response = await this.client.get('/executions', { params })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async getExecution(id) {
    try {
      const response = await this.client.get(`/executions/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  async deleteExecution(id) {
    try {
      const response = await this.client.delete(`/executions/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  }

  handleError(error) {
    if (error.response) {
      console.error('n8n API Error:', error.response.status, error.response.data)

      const customError = new Error(error.response.data.message || 'n8n API error')
      customError.status = error.response.status
      customError.data = error.response.data
      return customError
    }

    if (error.request) {
      console.error('n8n Connection Error:', error.message)
      const customError = new Error('Unable to connect to n8n API')
      customError.status = 503
      return customError
    }

    console.error('Unexpected Error:', error)
    return error
  }
}

module.exports = new N8nClient()
