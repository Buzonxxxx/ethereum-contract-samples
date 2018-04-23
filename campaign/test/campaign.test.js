const assert = require('assert')
const ganache = require('ganache-cli')
//constructor
const Web3 = require('web3')
//instance
const web3 = new Web3(ganache.provider())
const compiledCampaign = require('../build/Campaign.json')
const compiledFactory = require('../build/CampaignFactory.json')

let accounts
let campaign
let factory
let campaignAddress

beforeEach(async () => {
  accounts = await web3.eth.getAccounts()

  factory = await new web3.eth.Contract(JSON.parse(compiledFactory.interface))
    .deploy({ data: compiledFactory.bytecode })
    .send({ from: accounts[0], gas: '1000000' })

  await factory.methods.createCampaign('100').send({
    from: account[0],
    gas: '1000000'
  })

  const address = await factory.methods.getDeployedCampaigns().call()
  campaignAddress = address[0]
  //已知地址, 可帶入地址
  campaign = await new web3.eth.Contract(
    JSON.parse(compiledCampaign.interface),
    campaignAddress
  )

})

describe('CampaignFactory Contract', () => {
  it('deploys a contract', () => {
    assert.ok(factory.options.address)
  }) 
})