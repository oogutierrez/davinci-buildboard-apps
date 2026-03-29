import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { getWorkflows, activateWorkflow, deactivateWorkflow, deleteWorkflow } from '../lib/api'
import { Workflow, Trash2, Eye } from 'lucide-react'
import './WorkflowList.css'

function WorkflowList() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const { data: workflows, isLoading } = useQuery({
    queryKey: ['workflows'],
    queryFn: async () => {
      const response = await getWorkflows()
      return response.data
    }
  })

  const activateMutation = useMutation({
    mutationFn: activateWorkflow,
    onSuccess: () => {
      queryClient.invalidateQueries(['workflows'])
    }
  })

  const deactivateMutation = useMutation({
    mutationFn: deactivateWorkflow,
    onSuccess: () => {
      queryClient.invalidateQueries(['workflows'])
    }
  })

  const deleteMutation = useMutation({
    mutationFn: deleteWorkflow,
    onSuccess: () => {
      queryClient.invalidateQueries(['workflows'])
    }
  })

  const handleToggleActive = (workflow) => {
    if (workflow.active) {
      deactivateMutation.mutate(workflow.id)
    } else {
      activateMutation.mutate(workflow.id)
    }
  }

  const handleDelete = (id) => {
    if (window.confirm('Are you sure you want to delete this workflow?')) {
      deleteMutation.mutate(id)
    }
  }

  if (isLoading) {
    return <div className="loading">Loading workflows...</div>
  }

  return (
    <div className="workflow-list-page">
      <div className="page-header">
        <h1 className="page-title">Workflows</h1>
        <div className="page-info">{workflows?.length || 0} workflows</div>
      </div>

      <div className="workflows-grid">
        {workflows?.map(workflow => (
          <div key={workflow.id} className="workflow-card">
            <div className="workflow-card-header">
              <div className="workflow-icon">
                <Workflow size={24} />
              </div>
              <div className={`workflow-badge ${workflow.active ? 'active' : workflow.triggerCount === 0 ? 'no-trigger' : 'inactive'}`}>
                {workflow.active ? 'Active' : workflow.triggerCount === 0 ? 'No trigger' : 'Inactive'}
              </div>
            </div>

            <h3 className="workflow-card-title">{workflow.name}</h3>
            <p className="workflow-card-meta">
              {workflow.nodes?.length || 0} nodes • Updated {new Date(workflow.updatedAt).toLocaleDateString()}
            </p>

            <div className="workflow-card-actions">
              <button
                className="btn-icon"
                onClick={() => navigate(`/workflows/${workflow.id}`)}
                title="View Details"
              >
                <Eye size={18} />
              </button>

              <span
                className="toggle-wrapper"
                title={!workflow.active && workflow.triggerCount === 0 ? 'Cannot activate: no trigger node' : workflow.active ? 'Deactivate' : 'Activate'}
              >
                <button
                  className={`toggle-switch ${workflow.active ? 'on' : 'off'}`}
                  onClick={() => handleToggleActive(workflow)}
                  disabled={!workflow.active && workflow.triggerCount === 0}
                  aria-label={workflow.active ? 'Deactivate' : 'Activate'}
                >
                  <span className="toggle-thumb" />
                </button>
              </span>

              <button
                className="btn-icon btn-danger"
                onClick={() => handleDelete(workflow.id)}
                title="Delete"
              >
                <Trash2 size={18} />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

export default WorkflowList
