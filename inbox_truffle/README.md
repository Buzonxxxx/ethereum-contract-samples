## Deploy contract to ethereum node bundled with truffle
1. Install truffle 
>`npm install truffle`
 
2. Porject init 
>`truffle init`

3. Launch truffle console 
>`truffle develop`

4. Deploy contract 
>`migrate --compile-all --reset`

5. Create instance: app 
>`Inbox.deployed().then(function(instance){app = instance;})`

6. Check instance 
>`app`

7. Call contract function 
>`app.message()`

8. Send Tx to change message 
>`app.setMessage("Change the string!!", {from: web3.eth.accounts[0]})`

- Check contract address `[Contract Name].address`
- Check accounts `web3.eth.accounts`

## Deploy contract to Ganache
1. Execute **Ganache** in your computer
2. Run 
>`truffle migrate --compile-all --reset --network ganache`
3. Enter truffle console 
>`truffle console --network ganache`
4. Create instance: app 
>`Inbox.deployed().then(function(instance){app = instance;})`

5. Check instance 
>`app`

6. Call contract function 
>`app.message()`

7. Send Tx to change message 
>`app.setMessage("Change the string!!", {from: web3.eth.accounts[0]})`