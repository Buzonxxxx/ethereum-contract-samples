import web3 from './web3'
import CampaignFactory from './build/CampaignFactory.json'

const instance = new web3.eth.Contract(
  JSON.parse(CampaignFactory.interface),
  '0xBBbFe81BE4C21d180A2491ACe73f09aa0d3af0aF'
)

export default instance