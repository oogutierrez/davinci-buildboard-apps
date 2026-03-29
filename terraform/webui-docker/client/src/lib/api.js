import axios from 'axios'
import { useAuthStore } from '../store/authStore'

const api = axios.create({
  baseURL: '/api'
})

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && error.config?.url !== '/auth/login') {
      useAuthStore.getState().logout()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// Auth
export const login = (credentials) => api.post('/auth/login', credentials)

// Workflows
export const getWorkflows = () => api.get('/workflows')
export const getWorkflow = (id) => api.get(`/workflows/${id}`)
export const activateWorkflow = (id) => api.post(`/workflows/${id}/activate`)
export const deactivateWorkflow = (id) => api.post(`/workflows/${id}/deactivate`)
export const deleteWorkflow = (id) => api.delete(`/workflows/${id}`)

// Executions
export const getExecutions = (params = {}) => api.get('/executions', { params })
export const getExecution = (id) => api.get(`/executions/${id}`)
export const deleteExecution = (id) => api.delete(`/executions/${id}`)

export default api
