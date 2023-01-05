const CONTRACT_ADDRESS = "0x3927c7b60076c8Da6ca8B2559aAeb33c87F92aFF"

async function mintNFT(contractAddress) {
   const WorkspaceRegistry = await ethers.getContractFactory("WorkspaceRegistry")
   const [owner] = await ethers.getSigners()
   console.log(await WorkspaceRegistry.attach(contractAddress).fetchWorkSpaces("0xaFE66D8156e9B66656B9e867530909e48E85ffbB"));
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
