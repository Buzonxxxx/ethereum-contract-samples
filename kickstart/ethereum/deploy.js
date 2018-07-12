const HDWalletProvider = require('truffle-hdwallet-provider')
const Web3 = require('web3')
const compiledFactory = require('./build/CampaignFactory.json')

const provider = new HDWalletProvider(
  'apple cry couch mobile wood wealth army sign betray then abstract loan',
  'https://rinkeby.infura.io/vLyWxwMRCxh44cqIEtUy'
)

const web3 = new Web3(provider)

const deploy = async () => {
  const accounts = await web3.eth.getAccounts()
  console.log('Attempting to deploy from account', accounts[0])

  const result = await new web3.eth.Contract(JSON.parse(compiledFactory.interface))
    .deploy({ data: '0x' + compiledFactory.bytecode })
    .send({ gas: '4700000', from: accounts[0] })
  
  console.log('Contract deployed to', result.options.address)
}

deploy()