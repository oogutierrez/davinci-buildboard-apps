import { useQuery } from '@tanstack/react-query'
import { getWorkflows, getExecutions } from '../lib/api'
import { Workflow, PlayCircle, CheckCircle2, XCircle, Clock } from 'lucide-react'
import './Dashboard.css'

function Dashboard() {
  const { data: workflows } = useQuery({
    queryKey: ['workflows'],
    queryFn: async () => {
      const response = await getWorkflows()
      return response.data
    }
  })

  const { data: executions } = useQuery({
    queryKey: ['recent-executions'],
    queryFn: async () => {
      const response = await getExecutions({ limit: 10 })
      return response.data
    }
  })

  const activeWorkflows = workflows?.filter(w => w.active).length || 0
  const totalWorkflows = workflows?.length || 0

  const executionData = executions?.data || []
  const successfulExecutions = executionData.filter(e => e.status === 'success').length
  const failedExecutions = executionData.filter(e => e.status === 'error').length

  return (
    <div className="dashboard">
      <h1 className="page-title">Dashboard</h1>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon" style={{ background: '#e0f2fe', color: '#0284c7' }}>
            <Workflow size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{totalWorkflows}</div>
            <div className="stat-label">Total Workflows</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: '#dcfce7', color: '#16a34a' }}>
            <CheckCircle2 size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{activeWorkflows}</div>
            <div className="stat-label">Active Workflows</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: '#dbeafe', color: '#2563eb' }}>
            <PlayCircle size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{executionData?.length || 0}</div>
            <div className="stat-label">Recent Executions</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: '#fee2e2', color: '#dc2626' }}>
            <XCircle size={24} />
          </div>
          <div className="stat-content">
            <div className="stat-value">{failedExecutions}</div>
            <div className="stat-label">Failed Executions</div>
          </div>
        </div>
      </div>

      <div className="dashboard-section">
        <h2 className="section-title">Recent Workflows</h2>
        <div className="workflow-list">
          {workflows?.slice(0, 5).map(workflow => (
            <div key={workflow.id} className="workflow-item">
              <div className="workflow-info">
                <h3 className="workflow-name">{workflow.name}</h3>
                <p className="workflow-meta">
                  {workflow.nodes?.length || 0} nodes • Updated {new Date(workflow.updatedAt).toLocaleDateString()}
                </p>
              </div>
              <div className={`workflow-status ${workflow.active ? 'active' : 'inactive'}`}>
                {workflow.active ? 'Active' : 'Inactive'}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export default Dashboard
