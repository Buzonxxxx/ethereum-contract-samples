const path = require('path')
const solc = require('solc')
const fs = require('fs-extra')

// delete entire build folder
const buildPath = path.resolve(__dirname, 'build')
fs.removeSync(buildPath)

const BoosterPath = path.resolve(__dirname, 'contracts', 'Booster.sol')
const UtilPath = path.resolve(__dirname, 'contracts', 'Util.sol')
const SafeMathPath = path.resolve(__dirname, 'contracts', 'SafeMath.sol')

var input = {
  'Util.sol': fs.readFileSync(UtilPath, 'utf8'),
  'SafeMath.sol': fs.readFileSync(SafeMathPath, 'utf8'),
  'Booster.sol': fs.readFileSync(BoosterPath, 'utf8'),
}

const output = solc.compile({sources: input}, 1).contracts

// check and create build folder
fs.ensureDirSync(buildPath)

// for..in loop: to iterate the keys of object
for (let contract in output) {
  fs.outputJsonSync(
    // path.resolve(buildPath, `${contract.replace(':', '')}.json`), 
    path.resolve(buildPath, `${contract}.json`), 
    output[contract]
  )
}