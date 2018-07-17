import React, { Component } from 'react'
import Layout from '../../components/Layout';
import { Button } from 'semantic-ui-react'
import factory from '../../ethereum/factory'
import web3 from '../../ethereum/web3'

class CampaignShow extends Component {
  state = {
    loading: false
  }

  render() {
    return (
      <Layout>
      <h3>Campaign Details</h3>
      <Button primary loading={this.state.loading}>View Requests</Button>
      </Layout>
    )
  }
}

export default CampaignShow