const { ethers } = require("hardhat")
const { Wallet } = ethers


// const lsdNetworkFactoryAddress = "0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1"
const lsdNetworkFactoryAddress = process.env.LSD_NETWORK_FACTORY_ADDRESS
console.log("ethers version:", ethers.version)

async function main() {
    if (!lsdNetworkFactoryAddress) throw new Error("lsd network factory address is required")

    const networkAdmin = new Wallet(process.env.ACCOUNT_NETWORK_ADMIN, ethers.provider)
    const voter1 = new Wallet(process.env.ACCOUNT_VOTER1, ethers.provider)
    const voter2 = new Wallet(process.env.ACCOUNT_VOTER2, ethers.provider)
    const voter3 = new Wallet(process.env.ACCOUNT_VOTER3, ethers.provider)
    const voters = [voter1, voter2, voter3]
    console.log("network admin account address:\t", networkAdmin.address)
    console.log("voter1 address:\t", voter1.address)
    console.log("voter2 address:\t", voter2.address)
    console.log("voter3 address:\t", voter3.address)

    console.log("ContractLsdNetworkFactory address:\t", lsdNetworkFactoryAddress)
    const ContractLsdNetworkFactory = await ethers.getContractAt("LsdNetworkFactory", lsdNetworkFactoryAddress, networkAdmin)

    await ContractLsdNetworkFactory
        .createLsdNetwork('rETH Test', 'rTETH', networkAdmin.address, voters.map(v => v.address), 2)
    
    const lsdTokens = await ContractLsdNetworkFactory.lsdTokensOfCreater(networkAdmin.address)
    const lsdTokenAddress = lsdTokens[lsdTokens.length - 1]
    console.log("LSDTokenAddress address:\t", lsdTokenAddress);

    const contracts = await ContractLsdNetworkFactory.networkContractsOfLsdToken(lsdTokenAddress)
    const ContractFeePool = await ethers.getContractAt("LsdNetworkFactory", contracts._feePool, networkAdmin)
    const ContractNetworkBalances = await ethers.getContractAt("INetworkBalances", contracts._networkBalances, networkAdmin)
    const ContractNetworkProposal = await ethers.getContractAt("INetworkProposal", contracts._networkProposal, networkAdmin)
    const ContractNodeDeposit = await ethers.getContractAt("INodeDeposit", contracts._nodeDeposit, networkAdmin)
    const ContractUserDeposit = await ethers.getContractAt("IUserDeposit", contracts._userDeposit, networkAdmin)
    const ContractNetworkWithdrawal = await ethers.getContractAt("INetworkWithdrawal", contracts._networkWithdrawal, networkAdmin)
    const ContractLsdToken = await ethers.getContractAt("LsdToken", contracts._lsdToken, networkAdmin)

    console.log("FeePoolAddress address:\t\t", ContractFeePool.address)
    console.log("NetworkBalancesAddress address:\t", ContractNetworkBalances.address)
    console.log("NetworkProposalAddress address:\t", ContractNetworkProposal.address)
    console.log("NodeDepositAddress address:\t", ContractNodeDeposit.address)
    console.log("UserDepositAddress address:\t", ContractUserDeposit.address)
    console.log("NetworkWithdrawalAddress address:\t", ContractNetworkWithdrawal.address)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
