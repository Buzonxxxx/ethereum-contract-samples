const path = require('path')
const fs = require('fs-extra')
const solc = require('solc')

// delete entire build folder
const buildPath = path.resolve(__dirname, 'build')
fs.removeSync(buildPath)

// __dirname: root directory
const campaignPath = path.resolve(__dirname, 'contracts', 'campaign.sol')
const source = fs.readFileSync(campaignPath, 'utf8')
const output = solc.compile(source, 1).contracts

// check and create build folder
fs.ensureDirSync(buildPath)

// for..in loop: to iterate the keys of object
for (let contract in output) {
  fs.outputJsonSync(
    path.resolve(buildPath, `${contract.replace(':', '')}.json`), 
    output[contract]
  )
  // console.log(path.resolve(buildPath, `${contract.replace(':', '')}.json`) )
}
