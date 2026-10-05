import Foundation
import CoreBluetooth
import CoreGraphics
import ImageIO

func short(_ n: Int) -> [UInt8] {
    precondition((0..<16384).contains(n))
    return n < 192 ? [UInt8(n)] : [0xc0 | UInt8(n >> 8), UInt8(n & 255)]
}

func label(_ path: String, darkness: UInt8? = nil) throws -> [UInt8] {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil), [384, 400].contains(image.width), image.height == 400 else {
        throw NSError(domain: "WePrint", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected a 384 × 400 native label or a 400 × 400 label image"])
    }
    var pixels = [UInt8](repeating: 255, count: 384 * 400)
    pixels.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: 384, height: 400, bitsPerComponent: 8,
                                bytesPerRow: 384, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
        context.interpolationQuality = image.width == 384 ? .none : .high
        context.draw(image, in: image.width == 384 ? CGRect(x: 0, y: 0, width: 384, height: 400) : CGRect(x: 0, y: 8, width: 384, height: 384))
    }
    var rows = [[UInt8]]()
    for y in 0..<400 {
        var row = [UInt8](repeating: 0, count: 48)
        for x in 0..<384 where pixels[y * 384 + x] < 160 {
            row[x / 8] |= 0x80 >> (x % 8)
        }
        rows.append(row)
    }
    let dots = rows.map { $0.reduce(0) { $0 + $1.nonzeroBitCount } }
    let peak = dots.max()!
    let averagePeak = (0..<dots.count).map { dots[max(0, $0 - 23)...$0].reduce(0, +) / 24 }.max()!
    let metrics = [0xc0 | UInt8(peak >> 8), UInt8(peak & 255), 0xc0 | UInt8(averagePeak >> 8), UInt8(averagePeak & 255)]
    var result = packet(0x20, [0, 1, 0, 0, 0, 0, 0, 0])
    if let darkness { result += packet(0x43, [darkness]) }
    result += packet(0x27, short(48)) + packet(0x26, short(400)) + packet(0x25, metrics)
    var y = 0
    while y < rows.count {
        let row = rows[y]
        var repeatCount = 1
        while y + repeatCount < rows.count && rows[y + repeatCount] == row { repeatCount += 1 }
        if let first = row.firstIndex(where: { $0 != 0 }), let last = row.lastIndex(where: { $0 != 0 }) {
            result += packet(0x21, short(repeatCount - 1) + short(first) + Array(row[first...last]))
        } else {
            result += packet(0x22, short(repeatCount - 1))
        }
        y += repeatCount
    }
    return result + packet(0x28) + packet(0x70) + packet(0x77, [0, 0])
}

func packet(_ command: UInt8, _ payload: [UInt8] = []) -> [UInt8] {
    precondition(payload.count < 16384)
    let n = payload.count
    var bytes: [UInt8] = [0x1f, command] + (n < 192 ? [UInt8(n)] : [0xc0 | UInt8(n >> 8), UInt8(n & 255)]) + payload
    bytes.append(~bytes.dropFirst().reduce(UInt8(0), &+))
    return bytes
}

func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }

final class WePrint: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var central: CBCentralManager!
    var printer: CBPeripheral?
    var writer: CBCharacteristic?
    var incoming: [UInt8] = []
    var outgoing: [UInt8] = []
    var offset = 0
    var finished = false
    var sendingPrint = false
    var status: UInt8?
    var dpi: Int?
    var width: Int?
    var credits = 0
    var sendScheduled = false
    var bufferFlags: UInt32?
    let name: String
    let printData: [UInt8]?

    init(name: String, printData: [UInt8]?) {
        self.name = name
        self.printData = printData
        super.init()
    }
    func finish(_ message: String, code: Int32 = 0) {
        guard !finished else { return }
        finished = true
        print(message)
        central.stopScan()
        if let printer { central.cancelPeripheralConnection(printer) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exit(code) }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if [.unauthorized, .unsupported, .poweredOff].contains(central.state) {
                finish("Bluetooth unavailable: \(central.state.rawValue)", code: 1)
            }
            return
        }
        central.scanForPeripherals(withServices: nil)
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard advertisedName == name, printer == nil else { return }
        printer = peripheral
        print("Connecting to \(name)")
        central.stopScan()
        peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: "FF00")])
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish("Connection failed: \(String(describing: error))", code: 1)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if !finished { finish("Printer disconnected before completion", code: 1) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first else {
            finish("FF00 service unavailable", code: 1); return
        }
        peripheral.discoverCharacteristics([CBUUID(string: "FF01"), CBUUID(string: "FF02"), CBUUID(string: "FF03")], for: service)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        writer = service.characteristics?.first { $0.uuid == CBUUID(string: "FF02") }
        guard error == nil, writer?.properties.contains(.writeWithoutResponse) == true,
              let notify = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "FF01") }) else {
            finish("Required write/notify characteristics unavailable", code: 1); return
        }
        peripheral.setNotifyValue(true, for: notify)
        guard let flow = service.characteristics?.first(where: { $0.uuid == CBUUID(string: "FF03") }) else {
            finish("FF03 flow control unavailable", code: 1); return
        }
        peripheral.setNotifyValue(true, for: flow)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.isNotifying else {
            finish("Notifications failed", code: 1); return
        }
        guard characteristic.uuid == CBUUID(string: "FF01") else { return }
        outgoing = [0x71, 0x72, 0x75, 0x79, 0x7c, 0x42, 0x43, 0x44, 0x70].flatMap { packet(UInt8($0)) } + packet(0x77, [0, 0])
        sendNext()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard !self.finished else { return }
            guard let data = self.printData else { self.finish("Read-only queries complete"); return }
            guard self.status == 0, self.dpi == 203, self.width == 384 else {
                self.finish("Print blocked: expected ready status 0, 203 DPI, and width 384 dots", code: 1); return
            }
            self.sendingPrint = true
            self.outgoing = data
            self.offset = 0
            print("Sending one label: \(data.count) bytes")
            self.sendNext()
        }
    }
    func sendNext() {
        guard !finished, !sendScheduled, let printer, let writer else { return }
        guard offset < outgoing.count else {
            if sendingPrint {
                sendingPrint = false
                print("All print bytes sent with printer credit flow control")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.status = nil
                    self.bufferFlags = nil
                    self.outgoing = packet(0x70) + packet(0x77, [0, 0])
                    self.offset = 0
                    self.sendNext()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    guard self.status == 0, self.bufferFlags == 0 else {
                        self.finish("Transmission ended, but printer completion is unconfirmed; inspect before retrying", code: 1)
                        return
                    }
                    self.finish("Printer ready, no command errors; inspect the physical label")
                }
            }
            return
        }
        guard credits > 0, printer.canSendWriteWithoutResponse else { return }
        let end = min(offset + 20, outgoing.count)
        credits -= 1
        printer.writeValue(Data(outgoing[offset..<end]), for: writer, type: .withoutResponse)
        offset = end
        sendScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.sendScheduled = false
            self.sendNext()
        }
    }
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) { sendNext() }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: "FF03") {
            let flow = Array(data)
            if flow.count >= 2, flow[0] == 1 { credits += Int(flow[1]); sendNext() }
            return
        }
        incoming += data
        while incoming.count >= 4 {
            guard incoming[0] == 0x1f else { incoming.removeFirst(); continue }
            let header = incoming[2] < 192 ? 3 : 4
            let length = header == 3 ? Int(incoming[2]) : (Int(incoming[2] & 0x3f) << 8) | Int(incoming[3])
            let count = header + length + 1
            guard incoming.count >= count else { return }
            let frame = Array(incoming.prefix(count))
            incoming.removeFirst(count)
            guard frame.last == 0x88 || frame.dropFirst().reduce(UInt8(0), &+) == 0xff else {
                finish("Invalid printer response checksum", code: 1); return
            }
            let command = frame[1]
            let payload = Array(frame[header..<(count - 1)])
            print("RX \(String(format: "%02x", command)): \(hex(payload))")
            if command == 0x77, payload.count >= 7 {
                let start = payload[0] < 192 ? 1 : 2
                if payload.count >= start + 4 {
                    bufferFlags = payload[start..<(start + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
                    print("Command buffer flags: \(String(format: "%08x", bufferFlags!))")
                }
            }
            if command == 0x70 { status = payload.first }
            if command == 0x71, payload.count == 1 { dpi = Int(payload[0]); print("DPI: \(dpi!)") }
            if payload.count >= 2 {
                let value = Int(payload[0]) << 8 | Int(payload[1])
                if command == 0x71 { dpi = value; print("DPI: \(value)") }
                if command == 0x72 { width = value; print("Printable width: \(value) dots") }
            }
            if command == 0x70, let status, status >= 12, printData != nil {
                finish("Printer error status \(status); stopping", code: 1)
            }
        }
    }
}

setbuf(stdout, nil)
let args = CommandLine.arguments
if args.count == 4 && args[1] == "--encode" {
    try Data(label(args[2])).write(to: URL(fileURLWithPath: args[3]))
    print("Encoded label without connecting to Bluetooth")
    exit(0)
}
if args.count == 2 && args[1] == "--self-test" {
    precondition(packet(0x70) == [0x1f, 0x70, 0, 0x8f])
    precondition(packet(0x27, [50]) == [0x1f, 0x27, 1, 50, 0xa5])
    precondition(packet(0x43, [13]) == [0x1f, 0x43, 1, 13, 0xae])
    for n in [0, 191, 192, 16383] {
        let p = packet(0x21, Array(repeating: 0x55, count: n))
        precondition(p.dropFirst().reduce(UInt8(0), &+) == 0xff)
        precondition(p.count == n + (n < 192 ? 4 : 5))
    }
    print("Protocol checks passed")
    exit(0)
}
guard (2...4).contains(args.count) else {
    print("Usage: weprint PRINTER_NAME [LABEL.png [DARKNESS_0_TO_14]] | --self-test | --encode LABEL.png OUTPUT.bin")
    exit(1)
}
var darkness: UInt8?
if args.count == 4 {
    guard let value = UInt8(args[3]), value <= 14 else {
        print("Darkness must be between 0 and 14 for this printer")
        exit(1)
    }
    darkness = value
}
let data: [UInt8]? = args.count >= 3 ? try label(args[2], darkness: darkness) : nil
let client = WePrint(name: args[1], printData: data)
client.central = CBCentralManager(delegate: client, queue: nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 90) { client.finish("Timed out", code: 1) }
RunLoop.main.run()
