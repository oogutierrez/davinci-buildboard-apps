const jwt = require('jsonwebtoken')

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production'

function authMiddleware(req, res, next) {
  try {
    const authHeader = req.headers.authorization

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ message: 'No token provided' })
    }

    const token = authHeader.substring(7)
    const decoded = jwt.verify(token, JWT_SECRET)

    req.user = decoded
    next()
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token' })
  }
}

function generateToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: '24h' }
  )
}

module.exports = {
  authMiddleware,
  generateToken
}
