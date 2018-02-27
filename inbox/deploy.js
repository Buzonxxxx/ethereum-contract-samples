const HDWalletProvider = require('truffle-hdwallet-provider')
const Web = require('web3')
const { interface, bytecode} = require('./compile')

const provider = new HDWalletProvider(
  'apple cry couch mobile wood wealth army sign betray then abstract loan',
  'https://rinkeby.infura.io/vLyWxwMRCxh44cqIEtUy '
)

const web3 = new Web3(provider)