const express = require('express')
const n8nClient = require('../lib/n8nClient')

const router = express.Router()

// Get all executions
router.get('/', async (req, res, next) => {
  try {
    const { limit, cursor, workflowId } = req.query

    const params = {}
    if (limit) params.limit = parseInt(limit)
    if (cursor) params.cursor = cursor
    if (workflowId) params.workflowId = workflowId

    const response = await n8nClient.getExecutions(params)
    res.json(response)
  } catch (error) {
    next(error)
  }
})

// Get a specific execution
router.get('/:id', async (req, res, next) => {
  try {
    const execution = await n8nClient.getExecution(req.params.id)
    res.json(execution)
  } catch (error) {
    next(error)
  }
})

// Delete an execution
router.delete('/:id', async (req, res, next) => {
  try {
    await n8nClient.deleteExecution(req.params.id)
    res.json({ success: true, message: 'Execution deleted' })
  } catch (error) {
    next(error)
  }
})

module.exports = router
