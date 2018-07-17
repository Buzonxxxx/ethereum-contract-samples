const routes = require('next-routes')()

// route mapping
routes
  .add('/campaigns/new', '/campaigns/new')
  .add('/campaigns/:address', '/campaigns/show')

module.exports = routes