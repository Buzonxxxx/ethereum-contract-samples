const assert = require('assert')
const ganache = require('ganache-cli')
const Web3 = require('web3')
const provider = ganache.provider()
const web3 = new Web3(provider)
const { interface, bytecode } = require('../compile')

let accounts
let myapp

beforeEach(async () => {
  accounts = await web3.eth.getAccounts()

  myapp = await new web3.eth.Contract(JSON.parse(interface))
    .deploy({ data: bytecode, })
    .send({ from: accounts[0], gas: '1000000' })

    myapp.setProvider(provider)
})

describe('MyApp', () => {
  it('deploys a contract', () => {
    assert.ok(myapp.options.address)｀｀
  })

  // it('has a default message', async () => {
  //   const message = await myapp.methods.textMessage().call()
  //   assert.equal(message, 'Hi, this is test.')
  // })

  // it('can set new message', async () => {
  //   await myapp.methods.setTextMessage('XDD').send( { from: accounts[0]})
  //   const message = await myapp.methods.textMessage().call()
  //   assert.equal(message, 'XDD')
  // })
})
