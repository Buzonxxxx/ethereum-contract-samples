const path = require('path')
const fs = require('fs')
const solc = require('solc')
// __dirname: root directory
const lotteryPath = path.resolve(__dirname, 'contracts', 'lottery.sol')
const source = fs.readFileSync(lotteryPath, 'utf8')

// console.log(solc.compile(source, 1))
module.exports = solc.compile(source, 1).contracts[':Lottery']


