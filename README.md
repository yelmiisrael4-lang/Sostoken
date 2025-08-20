# Sostoken - Emergency SOS Signal Token

A decentralized emergency response system built on Stacks blockchain that allows users to create distress beacons and enables community-driven emergency assistance with token incentives.

## Features

- **Emergency Signal Creation**: Create SOS signals with location, description, and reward pool
- **Community Response System**: Community members can respond to active signals
- **Token Rewards**: Responders earn tokens for verified helpful responses
- **Reputation System**: Track user reliability and response quality
- **Signal Management**: Extend, escalate, cancel, or resolve emergency signals
- **Emergency Contacts**: Manage emergency contact networks

## Contract Functions

### Core Token Functions
- `get-balance (who principal)` - Get user's token balance
- `transfer (amount uint) (from principal) (to principal) (memo)` - Transfer tokens
- `mint (amount uint) (recipient principal)` - Mint tokens (owner only)

### Emergency Signal Functions
- `create-sos-signal (emergency-type description latitude longitude reward-amount)` - Create new SOS signal
- `respond-to-signal (signal-id response-message response-type)` - Respond to active signal
- `resolve-signal (signal-id successful)` - Mark signal as resolved (creator only)
- `cancel-signal (signal-id)` - Cancel active signal (creator only)
- `extend-signal (signal-id additional-blocks)` - Extend signal duration
- `escalate-signal (signal-id)` - Increase signal priority with additional fee

### Community Functions
- `vote-helpful (signal-id responder)` - Vote response as helpful (signal creator only)
- `verify-response (signal-id responder)` - Verify response and reward responder
- `claim-expired-signal (signal-id)` - Claim rewards from expired signals

### Management Functions
- `add-emergency-contact (contact-principal contact-name priority-level auto-notify)` - Add emergency contact
- `update-emergency-settings (new-fee new-reward new-duration)` - Update contract settings (owner only)

## Usage Examples

### Creating an Emergency Signal
```clarity
(contract-call? .Sostoken create-sos-signal "medical" "Heart attack at home" 40712345 -74005678 u100)
```

### Responding to a Signal
```clarity
(contract-call? .Sostoken respond-to-signal u1 "Ambulance dispatched to your location" "emergency-services")
```

### Resolving a Signal
```clarity
(contract-call? .Sostoken resolve-signal u1 true)
```

## Emergency Types
- `medical` - Medical emergencies
- `fire` - Fire emergencies  
- `accident` - Traffic or other accidents
- `crime` - Criminal activity or threats
- `natural` - Natural disasters
- `mechanical` - Vehicle breakdowns
- `lost` - Missing persons or lost situations

## Response Types
- `emergency-services` - Professional emergency response
- `volunteer-help` - Community volunteer assistance
- `information` - Helpful information or guidance
- `resources` - Providing resources or supplies
- `coordination` - Helping coordinate response efforts

## Token Economics

- **Emergency Fee**: Default 10 tokens to create signal (prevents spam)
- **Responder Reward**: Default 50 tokens for verified helpful responses
- **Signal Duration**: Default 144 blocks (~24 hours)
- **Extension Cost**: 2 tokens per additional block
- **Escalation Fee**: 25 tokens to increase signal priority

## Development

### Setup
```bash
npm install
clarinet check
```

### Testing
```bash
npm test
```

### Deployment
```bash
clarinet deploy --testnet
```

## License

MIT License
