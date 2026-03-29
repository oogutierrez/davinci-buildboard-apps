const express = require('express')
const bcrypt = require('bcryptjs')
const { generateToken } = require('../middleware/auth')

const router = express.Router()

// In production, replace this with a proper database
const users = [
  {
    id: '1',
    username: process.env.ADMIN_USERNAME || 'admin',
    password: bcrypt.hashSync(process.env.ADMIN_PASSWORD || 'admin123', 10)
  }
]

router.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body

    if (!username || !password) {
      return res.status(400).json({ message: 'Username and password are required' })
    }

    const user = users.find(u => u.username === username)

    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' })
    }

    const isValidPassword = await bcrypt.compare(password, user.password)

    if (!isValidPassword) {
      return res.status(401).json({ message: 'Invalid credentials' })
    }

    const token = generateToken(user)

    res.json({
      token,
      user: {
        id: user.id,
        username: user.username
      }
    })
  } catch (error) {
    next(error)
  }
})


module.exports = router
