import { Outlet, NavLink, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../store/authStore'
import { LayoutDashboard, Workflow, PlayCircle, LogOut } from 'lucide-react'
import './Layout.css'

function Layout() {
  const navigate = useNavigate()
  const { user, logout } = useAuthStore()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="sidebar-header">
          <h1 className="logo">n8n Custom UI</h1>
        </div>

        <nav className="nav">
          <NavLink to="/" end className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            <LayoutDashboard size={20} />
            <span>Dashboard</span>
          </NavLink>

          <NavLink to="/workflows" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            <Workflow size={20} />
            <span>Workflows</span>
          </NavLink>

          <NavLink to="/executions" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
            <PlayCircle size={20} />
            <span>Executions</span>
          </NavLink>
        </nav>

        <div className="sidebar-footer">
          <div className="user-info">
            <div className="user-avatar">{user?.username?.[0]?.toUpperCase() || 'U'}</div>
            <span className="user-name">{user?.username || 'User'}</span>
          </div>
          <button onClick={handleLogout} className="logout-btn">
            <LogOut size={18} />
          </button>
        </div>
      </aside>

      <main className="main-content">
        <Outlet />
      </main>
    </div>
  )
}

export default Layout
