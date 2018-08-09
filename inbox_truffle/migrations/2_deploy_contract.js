const Inbox = artifacts.require("./inbox.sol")

module.exports = function(deployer) {
  deployer.deploy(Inbox, 'Hi there!')
}