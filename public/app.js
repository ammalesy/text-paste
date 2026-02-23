/* ── Page switching ───────────────────────────── */
function showPage(page) {
  document.getElementById('page-paste').classList.toggle('active', page === 'paste');
  document.getElementById('page-records').classList.toggle('active', page === 'records');
  document.getElementById('btn-paste').classList.toggle('active', page === 'paste');
  document.getElementById('btn-records').classList.toggle('active', page === 'records');

  if (page === 'records') loadRecords();
}

/* ── Character counter ────────────────────────── */
const textInput = document.getElementById('textInput');
const charCount  = document.getElementById('charCount');

textInput.addEventListener('input', () => {
  const n = textInput.value.length;
  charCount.textContent = `${n.toLocaleString()} ตัวอักษร`;
});

/* ── Save text ────────────────────────────────── */
async function saveText() {
  const text = textInput.value.trim();
  if (!text) {
    showToast('กรุณาวางข้อความก่อนบันทึก', 'error');
    return;
  }

  const btn   = document.getElementById('saveBtn');
  const label = document.getElementById('saveBtnLabel');
  btn.disabled = true;
  label.textContent = '⏳ กำลังบันทึก…';

  try {
    const res  = await fetch('/api/save', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text }),
    });
    const data = await res.json();

    if (res.ok) {
      showToast(`✅ บันทึกสำเร็จ: ${data.filename}`, 'success');
      textInput.value = '';
      charCount.textContent = '0 ตัวอักษร';
    } else {
      showToast(`❌ เกิดข้อผิดพลาด: ${data.error}`, 'error');
    }
  } catch (err) {
    showToast('❌ ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', 'error');
  } finally {
    btn.disabled = false;
    label.textContent = '💾 บันทึก';
  }
}

/* ── Toast ────────────────────────────────────── */
let toastTimer;
function showToast(msg, type) {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = `toast ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { toast.className = 'toast hidden'; }, 4000);
}

/* ── Load records ─────────────────────────────── */
async function loadRecords() {
  const list = document.getElementById('recordsList');
  list.innerHTML = '<p class="loading">กำลังโหลด…</p>';

  try {
    const res  = await fetch('/api/records');
    const data = await res.json(); // { "2026-02-23": ["2026-02-23T14-05-30-record.txt", ...], ... }

    const dates = Object.keys(data);
    if (dates.length === 0) {
      list.innerHTML = '<p class="empty">ยังไม่มีบันทึก</p>';
      return;
    }

    list.innerHTML = '';
    dates.forEach((date) => {
      const group = document.createElement('div');
      group.className = 'day-group';

      const header = document.createElement('div');
      header.className = 'day-header';
      header.textContent = formatDate(date);
      group.appendChild(header);

      data[date].forEach((entry) => {
        // entry is { filename, url }
        const item = document.createElement('div');
        item.className = 'record-item';
        item.onclick = () => openRecord(entry.filename, entry.url);

        const time = document.createElement('span');
        time.className = 'record-time';
        time.textContent = formatTime(entry.filename);

        const name = document.createElement('span');
        name.className = 'record-name';
        name.textContent = entry.filename;

        const arrow = document.createElement('span');
        arrow.className = 'record-arrow';
        arrow.textContent = '›';

        item.appendChild(time);
        item.appendChild(name);
        item.appendChild(arrow);
        group.appendChild(item);
      });

      list.appendChild(group);
    });
  } catch (err) {
    list.innerHTML = '<p class="empty">ไม่สามารถโหลดข้อมูลได้</p>';
  }
}

/* ── Open a single record ─────────────────────── */
async function openRecord(filename, blobUrl) {
  const modal   = document.getElementById('modal');
  const title   = document.getElementById('modalTitle');
  const content = document.getElementById('modalContent');

  title.textContent   = filename;
  content.textContent = 'กำลังโหลด…';
  modal.classList.remove('hidden');

  try {
    const res  = await fetch(blobUrl);
    content.textContent = res.ok ? await res.text() : 'ไม่สามารถโหลดข้อมูลได้';
  } catch {
    content.textContent = 'ไม่สามารถโหลดข้อมูลได้';
  }
}

function closeModal() {
  document.getElementById('modal').classList.add('hidden');
}

// Close modal on backdrop click
document.getElementById('modal').addEventListener('click', (e) => {
  if (e.target === document.getElementById('modal')) closeModal();
});

/* ── Helpers ──────────────────────────────────── */
function formatDate(dateStr) {
  // dateStr = "2026-02-23"
  const d = new Date(dateStr + 'T00:00:00');
  return d.toLocaleDateString('th-TH', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
}

function formatTime(filename) {
  // filename = "2026-02-23T14-05-30-record.txt"
  const parts = filename.split('T');
  if (parts.length < 2) return '';
  const timePart = parts[1].slice(0, 8).replace(/-/g, ':'); // "14:05:30"
  return timePart;
}
