const { ethers, web3 } = require('hardhat')
const { expect } = require('chai')

describe('LsdNetwok test', function () {
  before(async function () {
    this.signers = await ethers.getSigners()

    this.AccountDeployer = this.signers[0]
    this.AccountFactoryAdmin = this.signers[1]

    this.AccountUser1 = this.signers[2]
    this.AccountSoloNode1 = this.signers[3]
    this.AccountTrustNode1 = this.signers[4]

    this.AccountProxyAdmin1 = this.signers[5]
    this.AccountNetworkAdmin1 = this.signers[6]
    this.AccountVoters1 = this.signers[7]
    this.AccountVoters2 = this.signers[8]
    this.FactoryProxyAdmin = this.signers[9]

    this.FactoryFeePool = await ethers.getContractFactory('FeePool', this.AccountDeployer)
    this.FactoryFeePoolV2Example = await ethers.getContractFactory('FeePoolV2Example', this.AccountDeployer)
    this.FactoryFeePoolV3Example = await ethers.getContractFactory('FeePoolV3Example', this.AccountDeployer)
    this.FactoryLsdNetworkFactory = await ethers.getContractFactory('LsdNetworkFactory', this.AccountDeployer)
    this.FactoryLsdToken = await ethers.getContractFactory('LsdToken', this.AccountDeployer)
    this.FactoryNetworkBalances = await ethers.getContractFactory('NetworkBalances', this.AccountDeployer)
    this.FactoryNetworkProposal = await ethers.getContractFactory('NetworkProposal', this.AccountDeployer)
    this.FactoryNodeDeposit = await ethers.getContractFactory('NodeDeposit', this.AccountDeployer)
    this.FactoryUserDeposit = await ethers.getContractFactory('UserDeposit', this.AccountDeployer)
    this.FactoryNetworkWithdrawal = await ethers.getContractFactory('NetworkWithdrawal', this.AccountDeployer)

    this.FactoryDepositContract = await ethers.getContractFactory('DepositContract', this.AccountDeployer)
    this.FactoryUUPSUpgradeableProxy = await ethers.getContractFactory("ERC1967Proxy", this.AccountDeployer)

    // deploy mock contracts
    this.ContractDepositContract = await this.FactoryDepositContract.deploy()
    await this.ContractDepositContract.deployed()
    console.log('ContractDepositContract address: ', this.ContractDepositContract.address)

    // deploy logic contracts
    this.ContractFeePoolLogic = await this.FactoryFeePool.deploy()
    await this.ContractFeePoolLogic.deployed()
    console.log('ContractFeePoolLogic address: ', this.ContractFeePoolLogic.address)

    this.ContractFeePoolV2ExampleLogic = await this.FactoryFeePoolV2Example.deploy()
    await this.ContractFeePoolV2ExampleLogic.deployed()
    console.log('ContractFeePoolV2ExampleLogic address: ', this.ContractFeePoolV2ExampleLogic.address)
        // this.FactoryFeePool = await ethers.getContractFactory("FeePool", this.AccountDeployer)
        // this.FactoryFeePoolV2Example = await ethers.getContractFactory("FeePoolV2Example", this.AccountDeployer)
        // this.FactoryFeePoolV3Example = await ethers.getContractFactory("FeePoolV3Example", this.AccountDeployer)
        // this.FactoryLsdNetworkFactory = await ethers.getContractFactory("LsdNetworkFactory", this.AccountDeployer)
        // this.FactoryLsdToken = await ethers.getContractFactory("LsdToken", this.AccountDeployer)
        // this.FactoryNetworkBalances = await ethers.getContractFactory("NetworkBalances", this.AccountDeployer)
        // this.FactoryNetworkProposal = await ethers.getContractFactory("NetworkProposal", this.AccountDeployer)
        // this.FactoryNodeDeposit = await ethers.getContractFactory("NodeDeposit", this.AccountDeployer)
        // this.FactoryUserDeposit = await ethers.getContractFactory("UserDeposit", this.AccountDeployer)
        // this.FactoryNetworkWithdrawal = await ethers.getContractFactory("NetworkWithdrawal", this.AccountDeployer)

        // this.FactoryDepositContract = await ethers.getContractFactory("DepositContract", this.AccountDeployer)
        // this.FactoryUUPSUpgradeableProxy = await ethers.getContractFactory("ERC1967Proxy", this.AccountDeployer)

    this.ContractFeePoolV3ExampleLogic = await this.FactoryFeePoolV3Example.deploy()
    await this.ContractFeePoolV3ExampleLogic.deployed()
    console.log('ContractFeePoolV3ExampleLogic address: ', this.ContractFeePoolV3ExampleLogic.address)

    this.ContractNetworkBalancesLogic = await this.FactoryNetworkBalances.deploy()
    await this.ContractNetworkBalancesLogic.deployed()
    console.log('ContractNetworkBalancesLogic address: ', this.ContractNetworkBalancesLogic.address)

    this.ContractNetworkProposalLogic = await this.FactoryNetworkProposal.deploy()
    await this.ContractNetworkProposalLogic.deployed()
    console.log('ContractNetworkProposalLogic address: ', this.ContractNetworkProposalLogic.address)

    this.ContractNodeDepositLogic = await this.FactoryNodeDeposit.deploy()
    await this.ContractNodeDepositLogic.deployed()
    console.log('ContractNodeDepositLogic address: ', this.ContractNodeDepositLogic.address)

    this.ContractUserDepositLogic = await this.FactoryUserDeposit.deploy()
    await this.ContractUserDepositLogic.deployed()
    console.log('ContractUserDepositLogic address: ', this.ContractUserDepositLogic.address)

    this.ContractNetworkWithdrawalLogic = await this.FactoryNetworkWithdrawal.deploy()
    await this.ContractNetworkWithdrawalLogic.deployed()
    console.log('ContractNetworkWithdrawalLogic address: ', this.ContractNetworkWithdrawalLogic.address)

    // deploy factory logic contract
    this.ContractLsdNetworkFactoryLogic = await this.FactoryLsdNetworkFactory.deploy()
    await this.ContractLsdNetworkFactoryLogic.deployed()
    console.log('ContractLsdNetworkFactoryLogic address: ', this.ContractLsdNetworkFactoryLogic.address)
  })

  beforeEach(async function () {
    // deploy factory proxy contract
    this.ContractUUPSUpgradeableProxy = await this.FactoryUUPSUpgradeableProxy.connect(this.FactoryProxyAdmin).deploy(
      this.ContractLsdNetworkFactoryLogic.address,
      "0x",
    )
    await this.ContractUUPSUpgradeableProxy.deployed()

    this.ContractLsdNetworkFactory = await ethers.getContractAt(
      'LsdNetworkFactory',
      this.ContractUUPSUpgradeableProxy.address,
    )
  })

  it('should createLsdNetwork success', async function () {
    // init factory
    await this.ContractLsdNetworkFactory.init(
      this.AccountFactoryAdmin.address,
      this.ContractDepositContract.address,
      this.ContractFeePoolLogic.address,
      this.ContractNetworkBalancesLogic.address,
      this.ContractNetworkProposalLogic.address,
      this.ContractNodeDepositLogic.address,
      this.ContractUserDepositLogic.address,
      this.ContractNetworkWithdrawalLogic.address,
    )

    console.log('ContractLsdNetworkFactory address: ', this.ContractLsdNetworkFactory.address)

    let createLsdNetworkTx = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient = await createLsdNetworkTx.wait()
    console.log('createLsdNetworkTx gas: ', createLsdNetworkTxRecipient.gasUsed.toString())

    let createLsdNetworkTx2 = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient2 = await createLsdNetworkTx2.wait()
    console.log('createLsdNetworkTx2 gas: ', createLsdNetworkTxRecipient2.gasUsed.toString())

    let createLsdNetworkWithTimelockTx = await this.ContractLsdNetworkFactory.connect(
      this.AccountUser1,
    ).createLsdNetworkWithTimelock(
      'test lsdEth',
      'lsdEth',
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
      1000,
      [this.AccountVoters1.address, this.AccountVoters2.address],
    )

    let createLsdNetworkWithTimelockTxRecipient = await createLsdNetworkWithTimelockTx.wait()
    console.log('createLsdNetworkWithTimelockTx gas: ', createLsdNetworkWithTimelockTxRecipient.gasUsed.toString())
  })

  it('should createLsdNetwork with feePoolV2Example success', async function () {
    // init factory
    await this.ContractLsdNetworkFactory.init(
      this.AccountFactoryAdmin.address,
      this.ContractDepositContract.address,
      this.ContractFeePoolV2ExampleLogic.address,
      this.ContractNetworkBalancesLogic.address,
      this.ContractNetworkProposalLogic.address,
      this.ContractNodeDepositLogic.address,
      this.ContractUserDepositLogic.address,
      this.ContractNetworkWithdrawalLogic.address,
    )
    console.log('ContractLsdNetworkFactory address: ', this.ContractLsdNetworkFactory.address)

    let createLsdNetworkTx = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient = await createLsdNetworkTx.wait()
    console.log('createLsdNetworkTx gas: ', createLsdNetworkTxRecipient.gasUsed.toString())

    let createLsdNetworkTx2 = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient2 = await createLsdNetworkTx2.wait()
    console.log('createLsdNetworkTx2 gas: ', createLsdNetworkTxRecipient2.gasUsed.toString())

    let createLsdNetworkWithTimelockTx = await this.ContractLsdNetworkFactory.connect(
      this.AccountUser1,
    ).createLsdNetworkWithTimelock(
      'test lsdEth',
      'lsdEth',
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
      1000,
      [this.AccountVoters1.address, this.AccountVoters2.address],
    )

    let createLsdNetworkWithTimelockTxRecipient = await createLsdNetworkWithTimelockTx.wait()
    console.log('createLsdNetworkWithTimelockTx gas: ', createLsdNetworkWithTimelockTxRecipient.gasUsed.toString())
  })

  it('should createLsdNetwork with feePoolV3Example success', async function () {
    // init factory
    await this.ContractLsdNetworkFactory.init(
      this.AccountFactoryAdmin.address,
      this.ContractDepositContract.address,
      this.ContractFeePoolV3ExampleLogic.address,
      this.ContractNetworkBalancesLogic.address,
      this.ContractNetworkProposalLogic.address,
      this.ContractNodeDepositLogic.address,
      this.ContractUserDepositLogic.address,
      this.ContractNetworkWithdrawalLogic.address,
    )
    console.log('ContractLsdNetworkFactory address: ', this.ContractLsdNetworkFactory.address)

    let createLsdNetworkTx = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient = await createLsdNetworkTx.wait()
    console.log('createLsdNetworkTx gas: ', createLsdNetworkTxRecipient.gasUsed.toString())

    let createLsdNetworkTx2 = await this.ContractLsdNetworkFactory.connect(this.AccountUser1).createLsdNetwork(
      'test lsdEth',
      'lsdEth',
      this.AccountNetworkAdmin1.address,
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
    )

    let createLsdNetworkTxRecipient2 = await createLsdNetworkTx2.wait()
    console.log('createLsdNetworkTx2 gas: ', createLsdNetworkTxRecipient2.gasUsed.toString())

    let createLsdNetworkWithTimelockTx = await this.ContractLsdNetworkFactory.connect(
      this.AccountUser1,
    ).createLsdNetworkWithTimelock(
      'test lsdEth',
      'lsdEth',
      [this.AccountVoters1.address, this.AccountVoters2.address],
      2,
      1000,
      [this.AccountVoters1.address, this.AccountVoters2.address],
    )

    let createLsdNetworkWithTimelockTxRecipient = await createLsdNetworkWithTimelockTx.wait()
    console.log('createLsdNetworkWithTimelockTx gas: ', createLsdNetworkWithTimelockTxRecipient.gasUsed.toString())
  })
})
