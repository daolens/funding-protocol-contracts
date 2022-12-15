async function deployContract() {
    const WORKSPACEREGISTRY = await ethers.getContractFactory("WorkspaceRegistry")
    const deployWORKSPACEREGISTRY = await WORKSPACEREGISTRY.deploy()
    await deployWORKSPACEREGISTRY.deployed()
    let txHash = deployWORKSPACEREGISTRY.deployTransaction.hash
    let txReceipt = await ethers.provider.waitForTransaction(txHash)
    let contractAddressWorkSpaceRegistry = txReceipt.contractAddress
    console.log("Workspace Registry Contract deployed to address:", contractAddressWorkSpaceRegistry)

    const APPLICATIONREGISTRY = await ethers.getContractFactory("ApplicationRegistry")
    const deployAPPLICATIONREGISTRY = await APPLICATIONREGISTRY.deploy(contractAddressWorkSpaceRegistry)
    await deployAPPLICATIONREGISTRY.deployed()
    txHash = deployAPPLICATIONREGISTRY.deployTransaction.hash
    txReceipt = await ethers.provider.waitForTransaction(txHash)
    let contractAddressApplicationRegistry = txReceipt.contractAddress
    console.log("Application Registry Contract deployed to address:", contractAddressApplicationRegistry)

    const GRANTFACTORY = await ethers.getContractFactory("GrantFactory")
    const deployGRANTFACTORY = await GRANTFACTORY.deploy(contractAddressWorkSpaceRegistry)
    await deployGRANTFACTORY.deployed()
    txHash = deployGRANTFACTORY.deployTransaction.hash
    txReceipt = await ethers.provider.waitForTransaction(txHash)
    let contractAddressGrantFactory = txReceipt.contractAddress
    console.log("Grant Factory Contract deployed to address:", contractAddressGrantFactory)
}
   
deployContract()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
