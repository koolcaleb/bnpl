// Import the OpenSea API client library
import "@opensea/api@2.0.0";

// Create an instance of the OpenSea API client
const client = new OpenSeaAPI({apiKey: "YOUR_API_KEY"});

// Set the NFT collection address and token ID
const collectionAddress = "0x123..."; // Replace with actual collection address
const tokenId = "456"; // Replace with actual token ID

// Fetch the floor price for the NFT collection
const { orders } = await client.api.getOrders({
  asset_contract_address: collectionAddress,
  token_id: tokenId,
  order_by: "created_date",
  order_direction: "asc",
  side: 1,
  limit: 1,
});

const floorPrice = orders[0].base_price;

// Set the maxLoanAmount to 50% of the floor price
uint public maxLoanAmount = floorPrice / 2;

