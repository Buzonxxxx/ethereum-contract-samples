const assert = require('assert')
const ganache = require('ganache-cli')
//constructor
const Web3 = require('web3')
//instance
const web3 = new Web3(ganache.provider())
const compiledCampaign = require('../ethereum/build/Campaign.json')
const compiledFactory = require('../ethereum/build/CampaignFactory.json')

let accounts
let campaign
let factory
let campaignAddress

beforeEach(async () => {
  accounts = await web3.eth.getAccounts()

  factory = await new web3.eth.Contract(JSON.parse(compiledFactory.interface))
    .deploy({ data: compiledFactory.bytecode })
    .send({ from: accounts[0], gas: '1000000' })
  
  await factory.methods.createCampaign('100')
    .send({ from: accounts[0], gas: '1000000' })

  const address = await factory.methods.getDeployedCampaigns().call()
  campaignAddress = address[0]
  
  campaign = await new web3.eth.Contract(JSON.parse(compiledCampaign.interface),campaignAddress)
})

describe('Campaigns', () => {
  it('deploys a factory and campaign', () => {
    assert.ok(factory.options.address)
    assert.ok(campaign.options.address)
  }) 
  it('marks caller as the campaign manager', async () => {
    manager = await campaign.methods.manager().call()
    assert.equal(accounts[0], manager)
  }) 
  it('allows people to contribute money and marks them as approvers', async () => {
    await campaign.methods.contribute()
    .send({ value: '200', from: accounts[1] })
    isContributor = await campaign.methods.approvers(accounts[1]) 
    assert(isContributor)
  }) 
  it('requires a minium contribution', async () => {
    try {
      await campaign.methods.contribute()
      .send({ value: '5', from: accounts[1] })
    } catch (err) {
      assert(err)
      return
    }
    assert(false)
  }) 
  it('allows a manager to make a payment request', async () => {
    await campaign.methods.createRequest('Buy batteries', '100', accounts[1])
    .send({ from: accounts[0], gas: '1000000' })
    
    request = await campaign.methods.requests(0).call()
    
    assert.equal('Buy batteries', request.description)
    assert.equal(accounts[1], request.recipient)
  })
  it('processes requests', async () => {
    await campaign.methods.contribute()
    .send({ from: accounts[0], value: web3.utils.toWei('10', 'ether') })

    await campaign.methods.createRequest('A', web3.utils.toWei('5', 'ether'), accounts[1])
      .send({ from: accounts[0], gas: '1000000' })

    await campaign.methods.approveRequest(0).send({
      from: accounts[0],
      gas: '100000'
    })

    await campaign.methods.finalizeRequest(0).send({
      from: accounts[0],
      gas: '100000'
    })

    let balance = await web3.eth.getBalance(accounts[1]) //string
    balance = web3.utils.fromWei(balance, 'ether')
    balance = parseFloat(balance) 
    assert(balance > 104)
  }) 
})