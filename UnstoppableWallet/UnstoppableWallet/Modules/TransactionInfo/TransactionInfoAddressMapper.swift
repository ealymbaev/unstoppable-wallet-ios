class TransactionInfoAddressMapper {
    private static let map = [
        // Ethereum Mainnet
        "0x7a250d5630b4cf539739df2c5dacb4c659f2488d": "Uniswap v.2",
        "0x11111112542d85b3ef69ae05771c2dccff4faa26": "1Inch V3",
        "0x881d40237659c251811cec9c364ef91dc08d300c": "Metamask: Swap Router",

        // Binanace Smart Chain
        "0x05ff2b0db69458a0750badebc4f9e13add608c7f": "PancakeSwap",
        "0x10ed43c718714eb63d5aa57b78b54704e256024e": "PancakeSwap v.2",
        "0xf84e3809971798bd372aecdc03ae977759a619ab": "Bunny Compensation Pool",
        "0xcadc8cb26c8c7cb46500e61171b5f27e9bd7889d": "Pancake Bunny: Bunny Pool",
    ]

    static func map(_ address: String) -> String {
        title(value: address) ?? String(address.prefix(5)) + "..." + String(address.suffix(5))
    }

    static func title(value: String) -> String? {
        map[value.lowercased()]
    }

}
