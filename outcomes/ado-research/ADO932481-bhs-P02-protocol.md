# BHS P02 Message Protocol Documentation

## Overview
The P02 message is used to send setup identification and customer orders (up to 3 customers) to the BHS Dry End system. The message contains setup parameters, side order information, customer-specific details, and preprint configuration.

## Message Structure

```
STX + "01" + "P0" + [Setup Section] + [Side Order] + [Customer 1] + [Customer 2] + [Customer 3] + [Preprint] + [Info Text] + ETX
```

### Message Header (4 bytes)
- **Message Number** (2): `01` - Sequential message identifier
- **Command** (2): `P0` - Command code for P02 message

---

## Setup Section (160 bytes)

| Field | Length | Format | Description | Example | Decoded Value |
|-------|--------|--------|-------------|---------|---------------|
| Setup ID | 20 | AN | Setup identification | `2975                ` | "2975" |
| Web Width | 6 | N | Web width in mm/100 | `282000` | 2820.00 mm |
| Edge Trim | 6 | N/B | Edge trim at knife 0 in mm/100 | `002200` | 22.00 mm |
| Quality ID | 12 | AN | Quality identification | `46B/KVK50 - ` | "46B/KVK50 -" |
| Flute Type | 4 | AN | Slitter scorer requirements | `V V ` | CB flute |
| White Top | 1 | N | White top indicator (0=No, 1=Yes) | `V` | Special code |
| Waterproof | 1 | N | Waterproof starch (0=No, 1=Yes) | `B` | Special code |
| Lineal Meters | 10 | N | Scheduled lineal meters in mm | `0000036110` | 36,110 mm |
| Caliper | 5 | N | Caliper in mm/1000 | `00025` | 0.025 mm |
| Speed Order Change | 6 | N | Speed on order change mm/min | `000000` | 0 mm/min |
| Speed After | 6 | N | Speed after order change mm/min | `000000` | 0 mm/min |
| Target Speed | 6 | N | Target speed corrugator mm/min | `000000` | 0 mm/min |
| Split Trim | 1 | N | Split trim flag (0=No, 1=Yes) | `0` | No |
| Guide Cutoff | 1 | N | Guide cutoff flag | `0` | No |
| Trim Code | 1 | N | Trim code | `1` | Code 1 |
| Reserved | 74 | AN | Reserved for future use | (spaces) | - |

---

## Side Order Section (8 bytes)

| Field | Length | Format | Description | Example | Decoded Value |
|-------|--------|--------|-------------|---------|---------------|
| Side Order Code | 1 | N | 0=No Side order, 1=Side order | `3` | Code 3 |
| Side Order Width | 6 | N | Sheet width in mm/100 | `000000` | 0.00 mm |
| Cutoff Allocation | 1 | N | Cutoff allocation | `0` | 0 |

---

## Customer Record Section (320 bytes × 3 = 960 bytes)

Each of the three customer records has identical structure:

### Customer Header (70 bytes)

| Field | Length | Format | Description | Example (C1) | Decoded Value |
|-------|--------|--------|-------------|--------------|---------------|
| Order Number | 20 | AN | Customer order number | `7881689050          ` | "7881689050" |
| Part Number | 3 | N/B | Part number | `   ` | (blank) |
| Customer Name | 20 | AN | Customer name | `INTERNAT P          ` | "INTERNAT P" |
| Processing Machine | 10 | AN | Processing machine ID | `3621      ` | "3621" |
| Destination Line | 1 | N | Destination line number | `1` | Line 1 |
| Nominal Cuts | 6 | N | Number of cuts | `002006` | 2,006 cuts |
| Number of Outs | 2 | N | Number of outs | `01` | 1 out |
| Sheet Length | 8 | N | Sheet length in mm/100 | `00180000` | 1,800.00 mm |
| Stack Height | 6 | N/B | Stack height in sheets | `000720` | 720 sheets |

### Scoring Configuration (192 bytes)

| Field | Length | Format | Description | Notes |
|-------|--------|--------|-------------|-------|
| Scoring Positions | 24×6=144 | N | 24 scoring/knife positions in mm/100 | Relative per out |
| Profile Selection | 24×1=24 | N | Profile selection for each position (1 or 2) | 1 or 2 |
| Scorer Type 1 | 1 | AN | Type of scorer profile 1 (default) | Profile code |
| Scorer Type 2 | 1 | AN | Type of scorer profile 2 (optional) | Profile code |
| Scorer Offset 1 | 2 | AN | Scorer offset profile 1 (default) | Offset code |
| Scorer Offset 2 | 2 | AN | Scorer offset profile 2 (optional) | Offset code |
| Score Depth 1 | 5 | N | Scoring depth profile 1 in mm/1000 | Default profile |
| Score Depth 2 | 5 | N | Scoring depth profile 2 in mm/1000 | Optional profile |

### Stacking Configuration (22 bytes)

| Field | Length | Format | Description | Notes |
|-------|--------|--------|-------------|-------|
| Side Chamber | 1 | N | Side chamber flag (0=No, 1=Yes) | - |
| Turn Over Outs | 1 | N | Turn over outs flag (0=No, 1=Yes) | - |
| Multi-stacking | 1 | N | Multi-stacking flag (0=No, 1=Yes) | Optional feature |
| Last Run | 1 | N | Last run flag (0=No, 1=Yes) | - |
| Stacks Widthwise | 2 | N | Number of stacks widthwise | If side chamber |
| Stacks Lengthwise | 2 | N | Number of stacks lengthwise | If side chamber |
| Stacks Above | 2 | N | Number of stacks above each other | If side chamber |
| Stack Group Width | 6 | N/B | Width of stack group in mm/100 | If available |
| Stack Group Outs | 2 | N/B | Number of outs for stack group | If available |

### Order Details (36 bytes)

| Field | Length | Format | Description | Notes |
|-------|--------|--------|-------------|-------|
| Sheet Width | 6 | N | Sheet width in mm/100 | - |
| Cutoff Allocation | 1 | N | Cutoff allocation | - |
| Discharge Direction | 1 | N | Discharge direction (0=OS, 1=DS) | OS/DS |
| Weight | 4 | N | Weight of one finished box in grams | - |
| Delivery Date | 8 | D | Date of delivery (YYYYMMDD) | Date format |
| Customer PO | 18 | AN | Customer purchase order | - |
| Outs Lengthwise | 2 | N | Outs on conveyor lengthwise | - |
| Outs Crosswise | 2 | N | Outs on conveyor crosswise | - |

### Palletizing & Finishing (14 bytes)

| Field | Length | Format | Description | Notes |
|-------|--------|--------|-------------|-------|
| Pallet Type | 2 | N | Pallet type (0-98, 0=No pallet) | Optional |
| Palletizing Layout | 3 | N | Palletizing layout code | Optional |
| Strapping Tension | 2 | N | Strapping tension (0-15) | - |
| Strapping Pattern | 2 | N | Strapping pattern code | - |
| Wrapping Code | 2 | N | Wrapping code (0-15) | Optional |
| Reserved | 3 | AN | Reserved | - |

---

## Preprint Section (59 bytes)

| Field | Length | Format | Description | Notes |
|-------|--------|--------|-------------|-------|
| Mark Cutoff 1 | 1 | N | Mark cutoff 1 flag | - |
| Mark Cutoff 2 | 1 | N | Mark cutoff 2 flag | - |
| Mark Cutoff 3 | 1 | N | Mark cutoff 3 flag | - |
| Mark Offset 1 | 8 | N | Mark offset cutoff 1 (+/- mm/100) | Signed |
| Mark Offset 2 | 8 | N | Mark offset cutoff 2 (+/- mm/100) | Signed |
| Mark Offset 3 | 8 | N | Mark offset cutoff 3 (+/- mm/100) | Signed |
| Preprint Mark 1 Width | 4 | N | Preprint mark 1 width mm/100 | - |
| Preprint Gap 1 Width | 4 | N | Preprint gap 1 width mm/100 | - |
| Preprint Mark 2 Width | 4 | N | Preprint mark 2 width mm/100 | - |
| Preprint Gap 2 Width | 4 | N | Preprint gap 2 width mm/100 | - |
| Preprint Mark 3 Width | 4 | N | Preprint mark 3 width mm/100 | - |
| Dimension Mark-Edge | 6 | N | Dimension mark to edge mm/100 | - |
| Window Width | 6 | N | Window width mm/100 | - |

---

## Information Text (80 bytes)

| Field | Length | Format | Description |
|-------|--------|--------|-------------|
| Information Text | 80 | AN | Free-form information text |

---

## Total Message Size

- Header: 4 bytes
- Setup: 160 bytes
- Side Order: 8 bytes
- Customer 1: 320 bytes
- Customer 2: 320 bytes
- Customer 3: 320 bytes
- Preprint: 59 bytes
- Information: 80 bytes
- **Total: 1,271 bytes** (excluding STX/ETX)

---

## Field Format Codes

- **N**: Numeric (numeric characters, right-justified, zero-padded)
- **AN**: Alphanumeric (letters, numbers, spaces)
- **N/B**: Numeric or Blank (numeric or spaces)
- **D**: Date format (YYYYMMDD)

---

## Example P02 Message Analysis

### Customer 1 Details
```
Order: 7881689050
Customer: INTERNAT P
Machine: 3621
Cuts: 2,006
Sheet Length: 1,800.00 mm
Stack Height: 720 sheets
Scoring Position 1: 487.00 mm
Score Depth: 61.003 mm
```

### Customer 2 Details
```
Order: 7881689060
Customer: INTERNAT P
Machine: 3633
Cuts: 1,644
Sheet Length: 2,196.00 mm
Stack Height: 720 sheets
Scoring Position 1: 763.00 mm
Score Depth: 26.002 mm
```

### Customer 3 Details
```
Order: 7881689080
Customer: INTERNAT P
Machine: 3621
Cuts: 1,644
Number of Outs: 2
Sheet Length: 2,196.00 mm
Stack Height: 720 sheets
Scoring Position 1: 763.00 mm
Score Depth: 26.002 mm
```

---

## Usage Example

### Sending Message
```bash
# Using the test script
bash bhs_dryend.sh | nc localhost 3001

# Or with the parser
bash bhs_p02_parser.sh
```

### Message Construction
See `bhs_p02_parser.sh` for detailed message construction functions and parsing logic.

---

## Notes

1. All numeric fields are right-justified and zero-padded
2. Alphanumeric fields are left-justified and space-padded
3. Measurements use specific divisors:
   - mm/100 for lengths (divide by 100 to get mm)
   - mm/1000 for caliper and scoring depth (divide by 1000 to get mm)
4. Optional fields may be blank (spaces) if not used
5. The message must be wrapped with STX (0x02) and ETX (0x03) bytes for transmission

---

## References

- BHS Protocol v4.2.2_Mexicali
- BHS-Corrugated GmbH Documentation
