const CONTRACT_ADDRESS = "0x74378f07F6B5d4B538556964F8b545Bb2d876690"

async function mintNFT(contractAddress) {
   const WorkspaceRegistry = await ethers.getContractFactory("WorkspaceRegistry")
   const [owner] = await ethers.getSigners()
   console.log(await WorkspaceRegistry.attach(contractAddress).fetchWorkSpaces("0x5B0Ef75235376d2A6FDcbE936CDad35D07fD8323"));
//    const txx = await tx.wait();
//    console.log(txx.events[0].args);
    // console.log(await WorkspaceRegistry.attach(contractAddress).submitApplication(
    //     "0xeCA650ca55cc2a0ECa185b832b2b87f39942402f",
    //     0,
    //     "QmTdbNwHu7ChBWJBgUMKj1GGRmauRa4ggQincWA58XqM6K",
    //     1,
    //     [])
    // )
//    console.log("Limited Added");
}

mintNFT(CONTRACT_ADDRESS)
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});
