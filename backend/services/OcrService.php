<?php
/**
 * =============================================================================
 * SERVICE INTEGRASI OCR PYTHON
 * =============================================================================
 * File ini bertugas untuk menjalankan script Python OCR KTP dari bahasa PHP:
 * 1. Mendeteksi executable Python di sistem operasi (Windows/Linux).
 * 2. Menjalankan script Python (`OCR-Script/ktp_ocr.py` / `ocr_processor.py`)
 *    melalui process execution `proc_open` secara aman.
 * 3. Menangkap keluaran stdout dan error stderr secara real-time.
 * 4. Melakukan decoding output JSON hasil OCR dan memvalidasi struktur data.
 * =============================================================================
 */

namespace Services;

use Exception;

class OcrService
{
    /**
     * @var string $pythonExecutable Path atau nama perintah eksekusi Python
     */
    private string $pythonExecutable;

    /**
     * @var string $ocrScriptPath Path absolut menuju script python OCR KTP
     */
    private string $ocrScriptPath;

    /**
     * Constructor: Inisialisasi path Python dan script OCR.
     */
    public function __construct()
    {
        // Pastikan file .env termuat
        \Config\Database::loadEnv();

        // Tentukan path script OCR di folder OCR-Script
        $projectRoot = dirname(__DIR__, 2);
        $this->ocrScriptPath = $projectRoot . '/OCR-Script/ktp_quick_scan.py';

        // Deteksi path python dari .env atau default sistem
        $envPython = getenv('PYTHON_PATH') ?: ($_ENV['PYTHON_PATH'] ?? null);
        if (!empty($envPython)) {
            $envPythonClean = trim($envPython, '"\'');
            if (file_exists($envPythonClean)) {
                $this->pythonExecutable = $envPythonClean;
            } elseif (file_exists($projectRoot . '/' . ltrim($envPythonClean, '/\\'))) {
                $this->pythonExecutable = $projectRoot . '/' . ltrim($envPythonClean, '/\\');
            } elseif (file_exists($projectRoot . '/backend/' . ltrim($envPythonClean, '/\\'))) {
                $this->pythonExecutable = $projectRoot . '/backend/' . ltrim($envPythonClean, '/\\');
            } else {
                $this->pythonExecutable = $this->detectPythonExecutable($envPythonClean);
            }
        } else {
            $this->pythonExecutable = $this->detectPythonExecutable();
        }
    }

    /**
     * Mendeteksi letak executable Python pada sistem operasi.
     * Mengutamakan virtual environment lokal project (backend/venv atau root venv) agar portabel di Windows maupun Linux server.
     *
     * @param string|null $preferredCmd Nama atau path prioritas jika ada
     * @return string Nama binary atau path python yang dapat dieksekusi
     */
    private function detectPythonExecutable(?string $preferredCmd = null): string
    {
        $projectRoot = dirname(__DIR__, 2);

        // 1. Cek virtual environment di dalam folder backend maupun project root
        $localVenvs = [
            $projectRoot . '/backend/venv/Scripts/python.exe',  // Windows backend/venv
            $projectRoot . '/backend/.venv/Scripts/python.exe', // Windows backend/.venv
            $projectRoot . '/backend/venv/bin/python',         // Linux/macOS backend/venv
            $projectRoot . '/backend/.venv/bin/python',        // Linux/macOS backend/.venv
            $projectRoot . '/venv/Scripts/python.exe',          // Windows root venv
            $projectRoot . '/.venv/Scripts/python.exe',         // Windows root .venv
            $projectRoot . '/venv/bin/python',                 // Linux/macOS root venv
            $projectRoot . '/.venv/bin/python',                // Linux/macOS root .venv
        ];

        foreach ($localVenvs as $venvPy) {
            if (file_exists($venvPy)) {
                return $venvPy;
            }
        }

        // 2. Cek preferred command jika diberikan
        if (!empty($preferredCmd)) {
            $testCmd = (DIRECTORY_SEPARATOR === '\\') ? "where.exe $preferredCmd 2>nul" : "which $preferredCmd 2>/dev/null";
            $output = @shell_exec($testCmd);
            if (!empty($output)) {
                return trim(explode("\n", trim($output))[0]);
            }
        }

        // 3. Cek binary Python standar di sistem
        $candidates = [
            'python3',
            'python',
            'py',
            'C:\\Windows\\py.exe',
        ];

        foreach ($candidates as $cmd) {
            if (file_exists($cmd)) {
                return $cmd;
            }
            $testCmd = (DIRECTORY_SEPARATOR === '\\') ? "where.exe $cmd 2>nul" : "which $cmd 2>/dev/null";
            $output = @shell_exec($testCmd);
            if (!empty($output)) {
                return trim(explode("\n", trim($output))[0]);
            }
        }

        return 'python';
    }

    /**
     * Menjalankan proses scan KTP menggunakan script Python.
     *
     * @param string $imagePath Path absolut ke file citra KTP
     * @return array Data terstruktur hasil ekstraksi OCR
     * @throws Exception Jika eksekusi gagal atau output JSON tidak valid
     */
    public function scanKtp(string $imagePath): array
    {
        if (!file_exists($imagePath)) {
            throw new Exception("File gambar KTP tidak ditemukan di: " . $imagePath);
        }

        if (!file_exists($this->ocrScriptPath)) {
            throw new Exception("Script OCR Python tidak ditemukan di: " . $this->ocrScriptPath);
        }

        // Siapkan parameter eksekusi dalam bentuk array agar aman dari spasi di Windows
        $pythonBin = trim($this->pythonExecutable, '"\'');
        $scriptPath = trim($this->ocrScriptPath, '"\'');
        $imgPath = trim($imagePath, '"\'');

        $command = [$pythonBin, $scriptPath, $imgPath, 'none'];

        // Siapkan descriptor pipes untuk proc_open
        $descriptorspec = [
            0 => ["pipe", "r"], // stdin
            1 => ["pipe", "w"], // stdout
            2 => ["pipe", "w"], // stderr
        ];

        // Menggunakan null untuk env agar child process mewarisi PATH dan variabel sistem Windows
        $process = proc_open($command, $descriptorspec, $pipes, dirname($this->ocrScriptPath), null);

        if (!is_resource($process)) {
            throw new Exception("Gagal membuat proses eksekusi script Python OCR.");
        }

        // Tutup stdin karena tidak memerlukan input interaktif
        fclose($pipes[0]);

        // Baca hasil stdout (JSON output dari python)
        $stdout = stream_get_contents($pipes[1]);
        fclose($pipes[1]);

        // Baca stderr jika terdapat warning / error log
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        // Dapatkan exit code proses
        $exitCode = proc_close($process);

        // Log stderr untuk keperluan debugging jika ada pesan
        if (!empty($stderr)) {
            error_log("[OCR Python Log] " . trim($stderr));
        }

        if (empty($stdout)) {
            throw new Exception("Script OCR Python [bin: {$pythonBin}] tidak menghasilkan output apapun. Error: " . ($stderr ?: "Exit code $exitCode"));
        }

        // Pastikan encoding string bersih dan valid UTF-8
        $cleanStdout = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $stdout);
        $cleanStdout = mb_convert_encoding($cleanStdout, 'UTF-8', 'UTF-8');

        // Decode output JSON dari stdout Python
        $decoded = json_decode(trim($cleanStdout), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            // Jika ada output teks sebelum JSON, coba temukan blok JSON
            $firstBrace = strpos($cleanStdout, '{');
            $lastBrace = strrpos($cleanStdout, '}');
            if ($firstBrace !== false && $lastBrace !== false && $lastBrace > $firstBrace) {
                $jsonSubstring = substr($cleanStdout, $firstBrace, $lastBrace - $firstBrace + 1);
                $decoded = json_decode($jsonSubstring, true);
            }
        }

        if (!is_array($decoded)) {
            throw new Exception("Gagal melakukan decode respon JSON dari OCR Python. Output mentah: " . substr($stdout, 0, 300));
        }

        if (isset($decoded['success']) && $decoded['success'] === false) {
            $msg = $decoded['error'] ?? $decoded['message'] ?? 'Proses OCR Python gagal.';
            throw new Exception("OCR Error: " . $msg);
        }

        // Ambil payload data KTP
        $extractedData = $decoded['data'] ?? $decoded;

        // Pastikan key-key penting tersedia
        return [
            'nama'      => $extractedData['nama'] ?? $extractedData['full_name'] ?? '',
            'nik'       => $extractedData['nik'] ?? $extractedData['document_number'] ?? '',
            'alamat'    => $extractedData['alamat'] ?? $extractedData['address'] ?? '',
            'foto_ktp'  => $extractedData['foto_ktp'] ?? null,
            'metadata'  => $extractedData['metadata'] ?? [],
            'raw_text'  => $decoded['raw_text'] ?? ''
        ];
    }
}
