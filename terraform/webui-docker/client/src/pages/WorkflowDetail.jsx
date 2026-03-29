import { useQuery } from '@tanstack/react-query'
import { useParams, useNavigate } from 'react-router-dom'
import { getWorkflow } from '../lib/api'
import { ArrowLeft, Calendar, GitBranch } from 'lucide-react'
import './WorkflowDetail.css'

function WorkflowDetail() {
  const { id } = useParams()
  const navigate = useNavigate()

  const { data: workflow, isLoading } = useQuery({
    queryKey: ['workflow', id],
    queryFn: async () => {
      const response = await getWorkflow(id)
      return response.data
    }
  })

  if (isLoading) {
    return <div className="loading">Loading workflow...</div>
  }

  if (!workflow) {
    return <div className="error">Workflow not found</div>
  }

  return (
    <div className="workflow-detail">
      <button className="btn-back" onClick={() => navigate('/workflows')}>
        <ArrowLeft size={20} />
        Back to Workflows
      </button>

      <div className="workflow-header">
        <div>
          <h1 className="workflow-title">{workflow.name}</h1>
          <div className="workflow-meta-info">
            <span className="meta-item">
              <Calendar size={16} />
              Updated {new Date(workflow.updatedAt).toLocaleString()}
            </span>
            <span className="meta-item">
              <GitBranch size={16} />
              {workflow.nodes?.length || 0} nodes
            </span>
          </div>
        </div>
        <div className={`status-badge ${workflow.active ? 'active' : 'inactive'}`}>
          {workflow.active ? 'Active' : 'Inactive'}
        </div>
      </div>

      <div className="workflow-sections">
        <section className="workflow-section">
          <h2 className="section-title">Workflow Information</h2>
          <div className="info-grid">
            <div className="info-item">
              <label>ID</label>
              <value>{workflow.id}</value>
            </div>
            <div className="info-item">
              <label>Created</label>
              <value>{new Date(workflow.createdAt).toLocaleString()}</value>
            </div>
            <div className="info-item">
              <label>Status</label>
              <value>{workflow.active ? 'Active' : 'Inactive'}</value>
            </div>
            <div className="info-item">
              <label>Nodes</label>
              <value>{workflow.nodes?.length || 0}</value>
            </div>
          </div>
        </section>

        <section className="workflow-section">
          <h2 className="section-title">Workflow Nodes</h2>
          <div className="nodes-list">
            {workflow.nodes?.map((node, index) => (
              <div key={node.id || index} className="node-card">
                <div className="node-icon">{node.type?.charAt(0).toUpperCase() || 'N'}</div>
                <div className="node-info">
                  <h4 className="node-name">{node.name}</h4>
                  <p className="node-type">{node.type}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {workflow.settings && (
          <section className="workflow-section">
            <h2 className="section-title">Settings</h2>
            <pre className="settings-code">{JSON.stringify(workflow.settings, null, 2)}</pre>
          </section>
        )}
      </div>
    </div>
  )
}

export default WorkflowDetail
