import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import WorkflowList from './pages/WorkflowList'
import WorkflowDetail from './pages/WorkflowDetail'
import ExecutionList from './pages/ExecutionList'
import Layout from './components/Layout'

function PrivateRoute({ children }) {
  const isAuthenticated = useAuthStore(state => state.isAuthenticated)
  return isAuthenticated ? children : <Navigate to="/login" replace />
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <PrivateRoute>
              <Layout />
            </PrivateRoute>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="workflows" element={<WorkflowList />} />
          <Route path="workflows/:id" element={<WorkflowDetail />} />
          <Route path="executions" element={<ExecutionList />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
