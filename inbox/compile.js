const path = require('path')
const fs = require('fs')
const solc = require('solc')
// __dirname: root directory
const inboxPath = path.resolve(__dirname, 'contracts', 'inbox.sol')
const source = fs.readFileSync(inboxPath, 'utf8')

// console.log(solc.compile(source).contracts[':Inbox'])
module.exports = solc.compile(source).contracts[':Inbox']