import web3 from './web3'
import CampaignFactory from './build/CampaignFactory.json'

const instance = new web3.eth.Contract(
  JSON.parse(CampaignFactory.interface),
  '0x6C5cc89Ba82094959094c0f95024D3363cDf4006'
)

export default instance