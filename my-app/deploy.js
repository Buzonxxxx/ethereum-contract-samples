const HDWalletProvider = require('truffle-hdwallet-provider')
const Web3 = require('web3')
const { interface, bytecode } = require('./compile')

const provider = new HDWalletProvider(
  'apple cry couch mobile wood wealth army sign betray then abstract loan',
  'https://rinkeby.infura.io/vLyWxwMRCxh44cqIEtUy',
)

const web3 = new Web3(provider)

const deploy = async () => {
  const accounts = await web3.eth.getAccounts()
  console.log('Attempting to deploy from accounts', accounts[0])

  const result = await new web3.eth.Contract(JSON.parse(interface))
    .deploy({ data: bytecode, arguments: ['Hi, this is test.'] })
    .send({ from: accounts[0], gas: '1000000' })
  console.log('Depoly to:', result.options.address)
}

deploy()