import web3 from './web3'
import CampaignFactory from './build/CampaignFactory.json'

const instance = new web3.eth.Contract(
  JSON.parse(CampaignFactory.interface),
  '0x08Df34cDDA822a0D22DF81B9C52A89A2bD4901DC'
)

export default instance