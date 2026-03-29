import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { getExecutions, deleteExecution } from '../lib/api'
import { CheckCircle2, XCircle, Clock, Trash2 } from 'lucide-react'
import './ExecutionList.css'

function ExecutionList() {
  const queryClient = useQueryClient()
  const [cursorHistory, setCursorHistory] = useState([null])
  const [pageIndex, setPageIndex] = useState(0)
  const limit = 20

  const currentCursor = cursorHistory[pageIndex]

  const { data, isLoading } = useQuery({
    queryKey: ['executions', currentCursor],
    queryFn: async () => {
      const params = { limit }
      if (currentCursor) params.cursor = currentCursor
      const response = await getExecutions(params)
      return response.data
    }
  })

  const deleteMutation = useMutation({
    mutationFn: deleteExecution,
    onSuccess: () => {
      queryClient.invalidateQueries(['executions'])
    }
  })

  const handleDelete = (id) => {
    if (window.confirm('Are you sure you want to delete this execution?')) {
      deleteMutation.mutate(id)
    }
  }

  const getStatusIcon = (execution) => {
    const status = execution.status

    if (status === 'running' || status === 'waiting') {
      return <Clock className="status-icon running" size={20} />
    }
    if (status === 'error') {
      return <XCircle className="status-icon failed" size={20} />
    }
    return <CheckCircle2 className="status-icon success" size={20} />
  }

  const getStatusText = (execution) => {
    const status = execution.status

    if (status === 'running') return 'Running'
    if (status === 'waiting') return 'Waiting'
    if (status === 'error') return 'Failed'
    return 'Success'
  }

  const getStatusClass = (execution) => {
    const status = execution.status

    if (status === 'running' || status === 'waiting') return 'running'
    if (status === 'error') return 'failed'
    return 'success'
  }

  if (isLoading) {
    return <div className="loading">Loading executions...</div>
  }

  return (
    <div className="execution-list-page">
      <div className="page-header">
        <h1 className="page-title">Executions</h1>
        <div className="page-info">{data?.data?.length || 0} executions</div>
      </div>

      <div className="execution-table-container">
        <table className="execution-table">
          <thead>
            <tr>
              <th>Status</th>
              <th>Workflow</th>
              <th>Started</th>
              <th>Finished</th>
              <th>Duration</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {data?.data?.map(execution => {
              const duration = execution.stoppedAt && execution.startedAt
                ? Math.round((new Date(execution.stoppedAt) - new Date(execution.startedAt)) / 1000)
                : null

              return (
                <tr key={execution.id}>
                  <td>
                    <div className={`execution-status ${getStatusClass(execution)}`}>
                      {getStatusIcon(execution)}
                      <span>{getStatusText(execution)}</span>
                    </div>
                  </td>
                  <td className="workflow-cell">
                    <div className="workflow-id">{execution.workflowId}</div>
                  </td>
                  <td>{new Date(execution.startedAt).toLocaleString()}</td>
                  <td>{execution.stoppedAt ? new Date(execution.stoppedAt).toLocaleString() : '-'}</td>
                  <td>{duration ? `${duration}s` : '-'}</td>
                  <td>
                    <button
                      className="btn-icon btn-danger"
                      onClick={() => handleDelete(execution.id)}
                      title="Delete"
                    >
                      <Trash2 size={16} />
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      <div className="pagination">
        <button
          onClick={() => setPageIndex(i => i - 1)}
          disabled={pageIndex === 0}
          className="pagination-btn"
        >
          Previous
        </button>
        <span className="pagination-info">Page {pageIndex + 1}</span>
        <button
          onClick={() => {
            const nextCursor = data?.nextCursor
            if (nextCursor) {
              setCursorHistory(h => {
                const next = [...h]
                next[pageIndex + 1] = nextCursor
                return next
              })
            }
            setPageIndex(i => i + 1)
          }}
          disabled={!data?.nextCursor}
          className="pagination-btn"
        >
          Next
        </button>
      </div>
    </div>
  )
}

export default ExecutionList
