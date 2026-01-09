# GAME DESIGN DOCUMENT  
## CROSSING REALITIES VERSUS

**Genre:** 2D Fighting Game  
**Platform:** PC  
**Target:** Local PvP  
**Control Scheme:** Keyboard-first  
**Status:** Pre-production GDD  

---

## 1. TẦM NHÌN & MỤC TIÊU THIẾT KẾ

### 1.1. Mục tiêu cốt lõi

Crossing Realities Versus được thiết kế để:

- Ưu tiên đấu đối kháng trực tiếp (local PvP)
- Tối ưu cho bàn phím, không yêu cầu motion inputs
- Nhấn mạnh **ra quyết định chiến thuật** thay vì execution phức tạp
- Tạo áp lực thông qua **tài nguyên, vị trí và nhịp độ**
- Tránh phụ thuộc vào mô hình high / low truyền thống

Game hướng tới người chơi đã quen với game đối kháng, sẵn sàng:
- Đọc tình huống
- Chấp nhận rủi ro
- Quản lý tài nguyên thay vì phòng thủ tuyệt đối

---

### 1.2. Triết lý thiết kế

> “Block là một lựa chọn, không phải trạng thái an toàn.”

- Không crouch
- Không overhead / low
- Phòng thủ tiêu hao tài nguyên và tích lũy rủi ro theo thời gian

Down không phải là thế đứng,  
mà là **một cam kết hành động**.

---

## 2. PHẠM VI & ĐỊNH HƯỚNG DỰ ÁN

### 2.1. Phạm vi giai đoạn đầu

**Bao gồm:**
- Local PvP
- UI cơ bản
- Không ưu tiên online ở giai đoạn đầu

---

## 3. ĐIỀU KHIỂN & INPUT SYSTEM

### 3.1. Movement Inputs (tay trái)

| Input | Chức năng |
|------|----------|
| Forward | Tiến |
| Back | Lùi |
| Up | Nhảy (tối đa 2 lần, gồm nhảy trên không) |
| Down | Block |

- Không crouch
- Giữ Down = block liên tục

---

### 3.2. Action Inputs (tay phải)

| Nút | Chức năng |
|----|----------|
| Light | Đòn nhẹ |
| Heavy | Đòn nặng |
| Special 1 | Kỹ năng |
| Special 2 | Kỹ năng |
| Special 3 | Kỹ năng |
| Dash | Lướt |

Tổng cộng **6 nút hành động**.

---

### 3.3. Modifier Rules

- Game **không sử dụng motion inputs**
- Modifier được xác định bằng input hướng
- Modifier + action phải được nhập trong cùng frame hoặc trong input window cho phép

#### Quy tắc ưu tiên

- **Down** là modifier kích hoạt bắt buộc cho mọi biến thể directional
- **Forward / Back** chỉ có hiệu lực khi được nhấn cùng **Down**, nếu không sẽ được hiểu là **Neutral**

- Khi tài liệu này nhắc tới **Forward / Back + Action**, thì tức input là **Down + Forward / Back + Action**.

---

## 4. HỆ THỐNG DI CHUYỂN & DASH

### 4.1. Nhảy

- 1 lần nhảy thường
- 1 lần nhảy trên không
- Điều khiển trên không linh hoạt, mang cảm giác platformer

---

### 4.2. Dash System (Universal)

| Input | Tên | Hiệu ứng | Stamina |
|------|----|----------|------|
| Dash | Dash | Lướt nhanh | Thấp |
| Down + Dash | Heavy Dash | Xuyên vật thể / đòn | Cao |
| Forward + Dash | Grab | Bắt block / đứng yên | 0 |
| Back + Dash | Evade | Né nhanh (i-frame) | 0 |

Dash là công cụ:
- Điều tiết nhịp độ
- Ép quyết định
- Không chỉ dùng để di chuyển

---

## 5. MOVE TAXONOMY (MỖI NHÂN VẬT)

### 5.1. Normals

#### Light Attacks (5)

- Neutral Light  
- Down + Light  
- Forward + Light  
- Back + Light  
- Air Light  

#### Heavy Attacks (3)

- Neutral Heavy  
- Down + Heavy  
- Air Heavy  

**Tổng Normals:** 8

---

### 5.2. Specials

Áp dụng cho **Special 1 / 2 / 3**.

| Trạng thái | Input |
|-----------|-------|
| Normal | Neutral, Down |
| Enhanced | Neutral, Down (khi kết hợp Dash hoặc điều kiện riêng) |

→ 2 biến thể / skill  
→ 3 skills  
→ **12 specials**

---

### 5.3. Ultimates

| Input | Loại |
|------|-----|
| S1 + S2 | Super |
| S2 + S3 | Super |
| S1 + S3 | Super |
| S1 + S2 + S3 | Ultimate |

Tổng: **4**

---

### 5.4. Universal Actions

- Dash
- Heavy Dash
- Evade
- Grab

---

### 5.5. Tổng số move

**28 moves / character**


---

## 6. RESOURCE SYSTEM

### 6.1. HP

- Thanh máu truyền thống
- Mặc định: **1000 HP**

---

### 6.2. Stamina (TRỤC THIẾT KẾ CHÍNH)

**Đặc điểm:**
- Hồi nhanh khi không hành động
- Bị ngắt hồi khi thực hiện hành động
- Không hồi khi giữ block

**Khi block trúng đòn:**
- Nhận chip damage
- Mất stamina

**Khi stamina = 0:**
- Nhân vật bị **Stunned**
- Không thể hành động trong một khoảng thời gian cố định
- Mở hoàn toàn cho punish

Block liên tục là lựa chọn có rủi ro.

---

### 6.3. Stamina Cost (Baseline)

| Hành động | Cost |
|----------|------|
| Dash | 10 |
| Heavy Dash | 30 |
| Light | ~3 |
| Heavy | ~6 |
| Special | ~10 |
| Evade / Grab | 0 |
| Ultimate | 0 |

---

### 6.4. Super / Meter

- Không có tiêu chuẩn chung
- Mỗi nhân vật có thể:
  - Dùng meter khác nhau
  - Hoặc không dùng meter
- Meter mang tính **character-specific**

---

## 7. STATUS & PASSIVE SYSTEM

### 7.1. Status

- Buff / Debuff / Stack
- Có thể cộng dồn
- Có thời gian hoặc điều kiện kết thúc

Ví dụ:
- Burn
- Armor
- Stack-based regeneration

---

### 7.2. Passive

Mỗi nhân vật phải có đúng **1 Passive**.

Passive:
- Thay đổi luật chơi
- Định hình archetype
- Không chỉ tăng chỉ số

Passive tốt:
- Có điều kiện kích hoạt
- Có rủi ro hoặc giới hạn
- Ép người chơi chọn lối chơi phù hợp

---

## 8. COMBO & DAMAGE SCALING

- Số hit tăng → damage giảm
- Combo dài → stamina tiêu hao nhiều hơn
- Giảm hiệu quả spam
- Khuyến khích combo có chủ đích thay vì kéo dài máy móc
