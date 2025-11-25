// Helper function to send MetaMask transaction
async function sendMetaMaskTransaction(from, to, value) {
  if (!window.ethereum) {
    throw new Error('MetaMask not installed');
  }
  
  try {
    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [
        {
          from: from,
          to: to,
          value: value,
        }
      ],
    });
    
    return txHash;
  } catch (error) {
    console.error('MetaMask transaction error:', error);
    throw error;
  }
}
