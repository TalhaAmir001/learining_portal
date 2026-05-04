<?php
/**
 * Download Center — upload a file into upload_contents (mobile companion to web upload).
 * POST multipart/form-data: file (required), content_type_id (required), upload_by (optional staff id).
 * Saves under ../uploads/download_center_mobile/ and inserts a row compatible with get_dc_upload_contents.php.
 */

header('Content-Type: application/json; charset=utf-8');

function dc_upload_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
}

/**
 * Resolves upload_by to a staff.id that exists (FK-safe). Smart School ties upload_by to staff.
 */
function dc_upload_resolve_staff_id(mysqli $mysqli, int $requested): array {
    if ($requested > 0) {
        $st = $mysqli->prepare('SELECT id FROM staff WHERE id = ? LIMIT 1');
        if ($st) {
            $st->bind_param('i', $requested);
            $st->execute();
            $st->store_result();
            if ($st->num_rows > 0) {
                $st->close();
                return ['id' => $requested, 'note' => 'used_client_staff_id'];
            }
            $st->close();
        }
    }
    $r = $mysqli->query('SELECT id FROM staff ORDER BY id ASC LIMIT 1');
    if ($r && $row = $r->fetch_assoc()) {
        $fid = (int) $row['id'];
        if ($fid > 0) {
            return [
                'id' => $fid,
                'note' => $requested > 0
                    ? 'client_id_not_in_staff_table_used_first_staff_row'
                    : 'no_client_id_used_first_staff_row',
            ];
        }
    }
    return ['id' => 0, 'note' => 'no_staff_rows'];
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    dc_upload_send_json(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$content_type_id = isset($_POST['content_type_id']) ? (int) $_POST['content_type_id'] : 0;
$upload_by_requested = isset($_POST['upload_by']) ? (int) $_POST['upload_by'] : 0;
$upload_by = $upload_by_requested;

if ($content_type_id <= 0) {
    dc_upload_send_json(['success' => false, 'error' => 'Missing or invalid content_type_id.']);
    exit;
}

$file_key = 'file';
if (empty($_FILES[$file_key]) || $_FILES[$file_key]['error'] !== UPLOAD_ERR_OK) {
    $err = $_FILES[$file_key]['error'] ?? 'no_file';
    dc_upload_send_json([
        'success' => false,
        'error' => 'Upload failed: ' . (is_int($err) ? 'error code ' . $err : (string) $err),
    ]);
    exit;
}

$file = $_FILES[$file_key];
$orig_name = isset($file['name']) ? (string) $file['name'] : '';
$tmp = isset($file['tmp_name']) ? (string) $file['tmp_name'] : '';

$allowed_exts = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf',
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg',
    'mp4', 'webm', 'mov', 'mp3', 'wav', 'm4a', 'zip', '7z', 'rar',
];
$max_size = 25 * 1024 * 1024; // 25 MB

$ext = strtolower(pathinfo($orig_name, PATHINFO_EXTENSION));
if ($ext === '' || !in_array($ext, $allowed_exts, true)) {
    dc_upload_send_json(['success' => false, 'error' => 'File type not allowed for this upload.']);
    exit;
}
if ($file['size'] > $max_size) {
    dc_upload_send_json(['success' => false, 'error' => 'File too large. Max 25 MB.']);
    exit;
}

$upload_dir = __DIR__ . '/../uploads/download_center_mobile';
if (!is_dir($upload_dir)) {
    if (!@mkdir($upload_dir, 0755, true)) {
        dc_upload_send_json(['success' => false, 'error' => 'Upload directory could not be created.']);
        exit;
    }
}

$safe_base = preg_replace('/[^a-zA-Z0-9._-]/', '_', basename($orig_name, '.' . $ext));
$save_name = bin2hex(random_bytes(8)) . '_' . substr($safe_base, 0, 48) . '.' . $ext;
$path = $upload_dir . '/' . $save_name;

if (!move_uploaded_file($tmp, $path)) {
    dc_upload_send_json(['success' => false, 'error' => 'Failed to save file on server.']);
    exit;
}

$mime = 'application/octet-stream';
if (function_exists('finfo_open')) {
    $f = finfo_open(FILEINFO_MIME_TYPE);
    if ($f) {
        $detected = finfo_file($f, $path);
        finfo_close($f);
        if (is_string($detected) && $detected !== '') {
            $mime = $detected;
        }
    }
}

$dir_path = 'uploads/download_center_mobile';
$real_name = $orig_name !== '' ? $orig_name : $save_name;
$file_size_str = (string) (int) $file['size'];

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');

    $chk = $mysqli->prepare('SELECT id FROM content_types WHERE id = ? LIMIT 1');
    if (!$chk) {
        throw new Exception('Prepare failed: ' . $mysqli->error);
    }
    $chk->bind_param('i', $content_type_id);
    $chk->execute();
    $chk->store_result();
    if ($chk->num_rows === 0) {
        $chk->close();
        $mysqli->close();
        @unlink($path);
        dc_upload_send_json(['success' => false, 'error' => 'Invalid content type.']);
        exit;
    }
    $chk->close();

    $resolved = dc_upload_resolve_staff_id($mysqli, $upload_by);
    if ($resolved['id'] <= 0) {
        $mysqli->close();
        @unlink($path);
        dc_upload_send_json([
            'success' => false,
            'error' => 'Could not resolve uploader: the staff table has no rows. Add staff in the web admin.',
            'mysql_errno' => 0,
            'mysql_error' => '',
            'upload_by_requested' => $upload_by_requested,
            'resolver_note' => $resolved['note'],
        ]);
        exit;
    }
    $upload_by = $resolved['id'];

    $image = $save_name;
    $thumb_path = '';
    $thumb_name = '';
    $vid_url = '';
    $vid_title = '';

    $sql = 'INSERT INTO upload_contents (
        content_type_id, image, thumb_path, dir_path, real_name, img_name, thumb_name,
        file_type, mime_type, file_size, vid_url, vid_title, upload_by, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())';

    $stmt = $mysqli->prepare($sql);
    if (!$stmt) {
        throw new Exception('Prepare insert failed: ' . $mysqli->error);
    }

    $stmt->bind_param(
        'i' . str_repeat('s', 11) . 'i',
        $content_type_id,
        $image,
        $thumb_path,
        $dir_path,
        $real_name,
        $save_name,
        $thumb_name,
        $ext,
        $mime,
        $file_size_str,
        $vid_url,
        $vid_title,
        $upload_by
    );

    if (!$stmt->execute()) {
        $errno = (int) $stmt->errno;
        $err = (string) $stmt->error;
        $stmt->close();
        $mysqli->close();
        @unlink($path);
        dc_upload_send_json([
            'success' => false,
            'error' => 'Database insert failed.',
            'mysql_errno' => $errno,
            'mysql_error' => $err,
            'details' => $errno !== 0 ? ($errno . ': ' . $err) : $err,
            'upload_by_requested' => $upload_by_requested,
            'upload_by_used' => $upload_by,
        ]);
        exit;
    }

    $new_id = (int) $stmt->insert_id;
    $stmt->close();
    $mysqli->close();

    dc_upload_send_json([
        'success' => true,
        'id' => $new_id,
        'message' => 'File uploaded and registered in the content library.',
        'upload_by_requested' => $upload_by_requested,
        'upload_by_used' => $upload_by,
        'upload_by_resolver_note' => $resolved['note'],
    ]);
} catch (Exception $e) {
    if (isset($mysqli) && $mysqli instanceof mysqli) {
        @$mysqli->close();
    }
    if (isset($path) && is_file($path)) {
        @unlink($path);
    }
    dc_upload_send_json([
        'success' => false,
        'error' => $e->getMessage(),
        'details' => $e->getMessage(),
    ]);
}
