const { ethers } = require("hardhat")
const { Wallet } = ethers

const ETHDepositContractAddress = "0xff50ed3d0ec03ac01d4c79aad74928bff48a7b2b"

async function main() {
    this.AccountDeployer = new Wallet(process.env.ACCOUNT_DEPLOYER, ethers.provider)
    this.AccountFactoryAdmin = new Wallet(process.env.ACCOUNT_FACTORY_ADMIN, ethers.provider)
    console.log("deployer account address:\t", this.AccountDeployer.address)
    console.log("factory account address:\t", this.AccountFactoryAdmin.address)

    this.FactoryFeePool = await ethers.getContractFactory("FeePool", this.AccountDeployer)
    this.FactoryLsdNetworkFactory = await ethers.getContractFactory("LsdNetworkFactory", this.AccountDeployer)
    this.FactoryLsdToken = await ethers.getContractFactory("LsdToken", this.AccountDeployer)
    this.FactoryNetworkBalances = await ethers.getContractFactory("NetworkBalances", this.AccountDeployer)
    this.FactoryNetworkProposal = await ethers.getContractFactory("NetworkProposal", this.AccountDeployer)
    this.FactoryNodeDeposit = await ethers.getContractFactory("NodeDeposit", this.AccountDeployer)
    this.FactoryUserDeposit = await ethers.getContractFactory("UserDeposit", this.AccountDeployer)
    this.FactoryNetworkWithdrawal = await ethers.getContractFactory("NetworkWithdrawal", this.AccountDeployer)

    this.FactoryERC1967Proxy = await ethers.getContractFactory("ERC1967Proxy", this.AccountDeployer)

    console.log("ETH ContractDepositContract address:\t", ETHDepositContractAddress)

    // deploy logic contract
    this.ContractFeePoolLogic = await this.FactoryFeePool.deploy()
    await this.ContractFeePoolLogic.deployed()
    console.log("ContractFeePoolLogic address:\t\t", this.ContractFeePoolLogic.address)


    this.ContractNetworkBalancesLogic = await this.FactoryNetworkBalances.deploy()
    await this.ContractNetworkBalancesLogic.deployed()
    console.log("ContractNetworkBalancesLogic address:\t", this.ContractNetworkBalancesLogic.address)

    this.ContractNetworkProposalLogic = await this.FactoryNetworkProposal.deploy()
    await this.ContractNetworkProposalLogic.deployed()
    console.log("ContractNetworkProposalLogic address:\t", this.ContractNetworkProposalLogic.address)


    this.ContractNodeDepositLogic = await this.FactoryNodeDeposit.deploy()
    await this.ContractNodeDepositLogic.deployed()
    console.log("ContractNodeDepositLogic address:\t", this.ContractNodeDepositLogic.address)

    this.ContractUserDepositLogic = await this.FactoryUserDeposit.deploy()
    await this.ContractUserDepositLogic.deployed()
    console.log("ContractUserDepositLogic address:\t", this.ContractUserDepositLogic.address)

    this.ContractNetworkWithdrawalLogic = await this.FactoryNetworkWithdrawal.deploy()
    await this.ContractNetworkWithdrawalLogic.deployed()
    console.log("ContractNetworkWithdrawalLogic address:\t", this.ContractNetworkWithdrawalLogic.address)

    // deploy factory logic contract
    this.ContractLsdNetworkFactoryLogic = await this.FactoryLsdNetworkFactory.deploy()
    await this.ContractLsdNetworkFactoryLogic.deployed()
    console.log("ContractLsdNetworkFactoryLogic address:\t", this.ContractLsdNetworkFactoryLogic.address)

    // deploy factory proxy contract
    this.ContractERC1967Proxy = await this.FactoryERC1967Proxy.deploy(this.ContractLsdNetworkFactoryLogic.address, "0x")
    await this.ContractERC1967Proxy.deployed()

    this.ContractLsdNetworkFactory = await ethers.getContractAt("LsdNetworkFactory", this.ContractERC1967Proxy.address)

    await this.ContractLsdNetworkFactory.connect(this.AccountDeployer).init(this.AccountFactoryAdmin.address,
        ETHDepositContractAddress, this.ContractFeePoolLogic.address, this.ContractNetworkBalancesLogic.address,
        this.ContractNetworkProposalLogic.address, this.ContractNodeDepositLogic.address,
        this.ContractUserDepositLogic.address, this.ContractNetworkWithdrawalLogic.address)

    console.log("ContractLsdNetworkFactory address:\t", this.ContractLsdNetworkFactory.address)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
