const express = require('express')
const cors = require('cors')
const helmet = require('helmet')
const path = require('path')
require('dotenv').config()

const authRoutes = require('./routes/auth')
const workflowRoutes = require('./routes/workflows')
const executionRoutes = require('./routes/executions')
const { authMiddleware } = require('./middleware/auth')

const app = express()
const PORT = process.env.PORT || 3000

// Middleware
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}))
app.use(cors({
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
}))
app.use(express.json())

// Debug middleware to log all requests
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`)
  next()
})

// API Routes
app.use('/api/auth', authRoutes)
app.use('/api/workflows', authMiddleware, workflowRoutes)
app.use('/api/executions', authMiddleware, executionRoutes)

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

// Basic health check for load balancers
app.get('/health', (req, res) => res.send('ok'))

// Serve static files in production (must be AFTER API routes)
if (process.env.NODE_ENV === 'production') {
  app.use(express.static(path.join(__dirname, '../client/dist')))

  // Catch-all for client-side routing (only for GET requests, and only for non-API paths)
  app.get('*', (req, res) => {
    // Don't catch API routes
    if (req.path.startsWith('/api')) {
      return res.status(404).json({ message: 'API endpoint not found' })
    }
    res.sendFile(path.join(__dirname, '../client/dist/index.html'))
  })
}

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err)
  res.status(err.status || 500).json({
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : {}
  })
})

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`)
  console.log(`n8n API URL: ${process.env.N8N_API_URL}`)
})
