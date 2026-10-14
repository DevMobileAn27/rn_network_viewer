# RN Network Viewer

Ứng dụng xem request, response và console log của app React Native trên macOS và Windows.

## Mở ứng dụng

1. Giải nén bản ứng dụng dành cho hệ điều hành của bạn.
2. **macOS:** kéo `RN Network Viewer.app` vào **Applications** rồi mở app.
3. **Windows:** mở file `.exe` trong thư mục đã giải nén. Giữ nguyên các file và thư mục đi kèm.
4. Kiểm tra góc trên bên phải hiển thị **Listening :38940**.

## Kết nối app React Native

### Thiết lập lần đầu

Trong dự án React Native, cài thư viện:

```sh
yarn add @quocandev27/rn_network_debugger
```

Với iOS, chạy thêm `pod install` trong thư mục `ios`.

Thêm vào file khởi chạy của app, trước `AppRegistry.registerComponent`:

```js
import {bootRNNetworkDebuggerWithPort} from '@quocandev27/rn_network_debugger';

if (__DEV__) {
  bootRNNetworkDebuggerWithPort(38940);
}
```

Build và chạy lại app React Native ở chế độ development.

### Bắt đầu xem dữ liệu

1. Mở **RN Network Viewer** trước.
2. Chạy hoặc Reload app React Native.
3. Thực hiện thao tác gọi API hoặc ghi console log trong app.
4. Chọn ứng dụng trong danh sách **Applications** để xem dữ liệu của ứng dụng đó. Chọn **All sessions** để xem tất cả.

Nhấn biểu tượng **?** trên thanh công cụ để mở hướng dẫn kết nối và xem địa chỉ máy tính.

### Chọn địa chỉ kết nối

Nếu cần chỉ định địa chỉ, thay đoạn khởi tạo ở trên bằng:

```js
import {bootRNNetworkDebugger} from '@quocandev27/rn_network_debugger';

if (__DEV__) {
  bootRNNetworkDebugger({
    VIEWER_HOST: '192.168.1.10',
    VIEWER_PORT: 38940,
  });
}
```

Thay `VIEWER_HOST` theo môi trường bạn đang dùng:

| Thiết bị chạy app React Native | Giá trị `VIEWER_HOST` |
| --- | --- |
| iOS Simulator trên cùng máy Mac | `127.0.0.1` |
| Android Emulator trên cùng máy tính | `10.0.2.2` |
| Thiết bị thật qua Wi-Fi | IP LAN của máy tính chạy Viewer, ví dụ `192.168.1.10` |
| Android qua USB | `127.0.0.1`, sau khi chạy lệnh bên dưới |

Với Android qua USB:

```sh
adb reverse tcp:38940 tcp:38940
```

Với thiết bị thật qua Wi-Fi, kết nối điện thoại và máy tính vào cùng mạng. Reload app React Native sau khi đổi địa chỉ hoặc cổng.

## Xem request và response

1. Mở tab **Network**.
2. Nhập từ khóa để tìm URL, method hoặc trạng thái. Dùng **All methods** và **All statuses** để lọc danh sách.
3. Chọn một request để mở chi tiết.

| Tab | Nội dung |
| --- | --- |
| **Overview** | Thông tin tổng quan, trạng thái, thời gian và query parameters |
| **Request** | Headers và Body gửi đi |
| **Response** | Headers và Body nhận về |
| **Raw** | Dữ liệu gốc của request được chọn |

Trong **Request** và **Response**:

- **Headers** mặc định thu gọn; nhấn mũi tên để mở.
- **Body** mặc định mở rộng. Chọn **JSON** để xem nội dung được thụt lề, tô màu và đánh số dòng.
- Chọn **Tree** để xem các nhánh dữ liệu. Nhấn vào object hoặc array để mở/thu gọn. Phần tử array được đánh dấu `[0]`, `[1]`, …
- Cuộn ngang để xem hết dòng dài.
- Nhấn biểu tượng sao chép cạnh **Headers** hoặc **Body** để copy nội dung.
- Nhấn biểu tượng terminal ở góc trên khung chi tiết để **Copy as cURL**.

Kéo đường chia giữa danh sách và khung chi tiết để thay đổi độ rộng. Nhấp đúp đường chia để trở về độ rộng mặc định. Phóng to cửa sổ nếu muốn xem danh sách và chi tiết cạnh nhau.

## Xem console log

1. Mở tab **Console**.
2. Nhập từ khóa để tìm nội dung hoặc tham số của log.
3. Dùng **All levels** để lọc theo `log`, `info`, `warn`, `error` hoặc `debug`.
4. Chọn một dòng để xem thông tin chi tiết. Mở các nhánh trong **Arguments** để xem object và array.

## Tạm dừng, xóa và lưu dữ liệu

Các nút nằm ở góc phải phía trên danh sách:

- **Pause / Resume:** tạm dừng hoặc tiếp tục nhận dữ liệu. Dữ liệu phát sinh trong lúc tạm dừng sẽ bị bỏ qua.
- **Clear:** xóa toàn bộ request và log đang có.
- **Export:** chọn nơi lưu file JSON. File bao gồm dữ liệu của tất cả ứng dụng, kể cả các mục đang bị ẩn bởi bộ lọc.

Xuất dữ liệu trước khi đóng Viewer nếu cần giữ lại lịch sử request và log.

## Cài đặt

Nhấn biểu tượng **bánh răng** để mở **Settings**.

| Cài đặt | Lựa chọn |
| --- | --- |
| **Language** | English hoặc Tiếng Việt |
| **Theme** | Light (Sáng) hoặc Dark (Đêm) |
| **WebSocket port** | Cổng kết nối, mặc định `38940` |

Ngôn ngữ và giao diện áp dụng ngay, được ghi nhớ cho lần mở app sau. Mặc định là **English** và **Light**.

Để đổi cổng:

1. Nhập cổng mới vào **WebSocket port**.
2. Nhấn **Save & restart**.
3. Đổi cổng trong đoạn khởi tạo thư viện ở app React Native cho trùng với Viewer, rồi Reload app. Nếu dùng Android qua USB, chạy lại `adb reverse` với cổng mới.

## Khi chưa thấy dữ liệu

1. Kiểm tra Viewer đang hiển thị **Listening**. Nếu đang dừng, nhấn nút **Start server** trên thanh công cụ.
2. Kiểm tra app React Native đã cài thư viện, thêm đoạn khởi tạo và đang chạy bản development.
3. Kiểm tra địa chỉ và cổng kết nối. Với thiết bị thật, kiểm tra điện thoại và máy tính đang cùng mạng.
4. Cho phép quyền **Local Network** trên macOS hoặc quyền kết nối qua firewall trên Windows nếu được hỏi.
5. Reload app React Native, sau đó thực hiện lại thao tác gọi API hoặc ghi log.
6. Chọn **All sessions**, xóa từ khóa tìm kiếm và đưa các bộ lọc về **All**.
7. Nếu Viewer báo cổng đang được sử dụng, đổi cổng trong **Settings** và cập nhật cổng ở app React Native.
