const path = require('path')
const fs = require('fs')
const solc = require('solc')

const myAppPath = path.resolve(__dirname, 'contracts', 'myapp.sol')
const source = fs.readFileSync(myAppPath, 'utf8')

// console.log(solc.compile(source, 1))
module.exports = solc.compile(source, 1).contracts[':MyApp']