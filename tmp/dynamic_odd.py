liquidity = 1_000_000

odd_A = 3
odd_B = 1

liquidity_A = odd_A / (odd_A + odd_B) * liquidity
print(f'liquidity A: {liquidity_A}')

def getOddSlip(odd, liquidity, bet_size):
    slip = min(odd, (odd * bet_size) / (liquidity - bet_size))
    return slip


print(odd_A - getOddSlip(odd_A, liquidity_A, 300_000))