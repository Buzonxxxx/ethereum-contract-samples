## Setup private node in local machine

1. brew install `ethereum`
2. Run `puppeth` to setup
3. Run 
> `geth --datadir ~/code/privateNode init cryptoLouis.json`
4. Create accounts
> `geth --datadir . account new`
5. Grant permission 
>`chmod +x startnode.sh`
6. Start the node
> `./startnode.sh`

##Geth javascript console
1. Run `geth attach`
2. check accounts
> `eth.accounts`
3. check coinbase
> `eth.coinbase`
4. get balance
> `eth.getBalance(eth.accounts[1])`
