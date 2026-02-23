/* ── Page switching ───────────────────────────── */
function showPage(page) {
  document.getElementById('page-paste').classList.toggle('active', page === 'paste');
  document.getElementById('page-records').classList.toggle('active', page === 'records');
  document.getElementById('btn-paste').classList.toggle('active', page === 'paste');
  document.getElementById('btn-records').classList.toggle('active', page === 'records');

  if (page === 'records') loadRecords(1);
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
let currentPage = 1;

async function loadRecords(page = 1) {
  currentPage = page;
  const list = document.getElementById('recordsList');
  list.innerHTML = '<p class="loading">กำลังโหลด…</p>';

  try {
    const res  = await fetch(`/api/records?page=${page}`);
    const data = await res.json(); // { grouped: {...}, pagination: {...} }

    const { grouped, pagination } = data;
    const dates = Object.keys(grouped || {});

    if (dates.length === 0) {
      list.innerHTML = '<p class="empty">ยังไม่มีบันทึก</p>';
      return;
    }

    list.innerHTML = '';

    // Record groups
    dates.forEach((date) => {
      const group = document.createElement('div');
      group.className = 'day-group';

      const header = document.createElement('div');
      header.className = 'day-header';
      header.textContent = formatDate(date);
      group.appendChild(header);

      grouped[date].forEach((entry) => {
        const item = document.createElement('div');
        item.className = 'record-item';

        const left = document.createElement('div');
        left.className = 'record-left';

        const time = document.createElement('span');
        time.className = 'record-time';
        time.textContent = formatTime(entry.filename);

        const preview = document.createElement('span');
        preview.className = 'record-preview';
        preview.textContent = entry.content;

        left.appendChild(time);
        left.appendChild(preview);

        const copyBtn = document.createElement('button');
        copyBtn.className = 'copy-btn';
        copyBtn.textContent = 'คัดลอก';
        copyBtn.onclick = (e) => {
          e.stopPropagation();
          copyAndDelete(entry.content, entry.filename, item);
        };

        item.appendChild(left);
        item.appendChild(copyBtn);
        group.appendChild(item);
      });

      list.appendChild(group);
    });

    // Pagination controls
    if (pagination && pagination.totalPages > 1) {
      const pager = document.createElement('div');
      pager.className = 'pagination';

      const prevBtn = document.createElement('button');
      prevBtn.className = 'page-btn';
      prevBtn.textContent = '← ก่อนหน้า';
      prevBtn.disabled = pagination.page <= 1;
      prevBtn.onclick = () => loadRecords(pagination.page - 1);

      const info = document.createElement('span');
      info.className = 'page-info';
      info.textContent = `หน้า ${pagination.page} / ${pagination.totalPages}`;

      const nextBtn = document.createElement('button');
      nextBtn.className = 'page-btn';
      nextBtn.textContent = 'ถัดไป →';
      nextBtn.disabled = pagination.page >= pagination.totalPages;
      nextBtn.onclick = () => loadRecords(pagination.page + 1);

      pager.appendChild(prevBtn);
      pager.appendChild(info);
      pager.appendChild(nextBtn);
      list.appendChild(pager);
    }

  } catch (err) {
    list.innerHTML = '<p class="empty">ไม่สามารถโหลดข้อมูลได้</p>';
  }
}

/* ── Copy then delete ─────────────────────────── */
async function copyAndDelete(text, filename, itemEl) {
  // 1. Copy to clipboard
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    showToast('ไม่สามารถคัดลอกได้', 'error');
    return;
  }

  // 2. Visual feedback on the row
  itemEl.classList.add('deleting');
  const btn = itemEl.querySelector('.copy-btn');
  btn.textContent = '✅ คัดลอกแล้ว';
  btn.disabled = true;

  // 3. Delete from server
  try {
    const res = await fetch(`/api/delete?filename=${encodeURIComponent(filename)}`, {
      method: 'DELETE',
    });
    if (!res.ok) {
      const data = await res.json();
      throw new Error(data.error || 'Delete failed');
    }
  } catch (err) {
    showToast(`❌ ลบไม่สำเร็จ: ${err.message}`, 'error');
    itemEl.classList.remove('deleting');
    btn.textContent = 'คัดลอก';
    btn.disabled = false;
    return;
  }

  // 4. Fade out the row
  itemEl.classList.add('removed');
  itemEl.addEventListener('transitionend', () => {
    const group = itemEl.closest('.day-group');
    itemEl.remove();
    // Remove the day group if no more items
    if (group && group.querySelectorAll('.record-item').length === 0) {
      group.remove();
    }
    // Show empty state if nothing left
    const list = document.getElementById('recordsList');
    if (!list.querySelector('.record-item')) {
      list.innerHTML = '<p class="empty">ยังไม่มีบันทึก</p>';
    }
  }, { once: true });
}

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
