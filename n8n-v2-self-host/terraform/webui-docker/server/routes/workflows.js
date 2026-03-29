const express = require('express')
const n8nClient = require('../lib/n8nClient')

const router = express.Router()

// Get all workflows
router.get('/', async (req, res, next) => {
  try {
    const workflows = await n8nClient.getWorkflows()
    res.json(workflows.data || workflows || [])
  } catch (error) {
    next(error)
  }
})

// Activate a workflow
router.post('/:id/activate', async (req, res, next) => {
  try {
    const workflow = await n8nClient.activateWorkflow(req.params.id)
    res.json(workflow)
  } catch (error) {
    next(error)
  }
})

// Deactivate a workflow
router.post('/:id/deactivate', async (req, res, next) => {
  try {
    const workflow = await n8nClient.deactivateWorkflow(req.params.id)
    res.json(workflow)
  } catch (error) {
    next(error)
  }
})

// Delete a workflow
router.delete('/:id', async (req, res, next) => {
  try {
    await n8nClient.deleteWorkflow(req.params.id)
    res.json({ success: true, message: 'Workflow deleted' })
  } catch (error) {
    next(error)
  }
})

// Get a specific workflow (keep this last as it's a catch-all for /:id)
router.get('/:id', async (req, res, next) => {
  try {
    const workflow = await n8nClient.getWorkflow(req.params.id)
    res.json(workflow)
  } catch (error) {
    next(error)
  }
})

module.exports = router
