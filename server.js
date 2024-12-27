const express = require('express');
const bodyParser = require('body-parser');
const multer = require('multer');
const { Pool } = require('pg');
const fa = require('fs');
const path = require('path');
const os = require('os');

const app = express();
const port = 8080;

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
	const destinationPath = '/home/judge/webserver/nfs_shared/';
    	cb(null, destinationPath);
    },
    filename: function (req, file, cb) {
    	cb(null, file.originalname);
    },
});

const upload = multer({ storage: storage });

const pool = new Pool({
  user: 'root',
  host: '192.168.123.1',
  database: 'sa-hw4',
  password: 'sa-hw4-123',
  port: 5432,
});

app.use(bodyParser.json());


app.get('/ip', (req, res) => {
    const ip = req.connection.remoteAddress || req.socket.remoteAddress;
    const serverhostname = os.hostname();
    res.json({ip, hostname: serverhostname});
});

//app.get('/file/:fileName', (req, res) => {
//    const fileName = req.params.fileName;
//    const filePath = path.join('/home/judge/webserver/nfs_shared/', fileName);  // Ensure file retrieval path is correct
//    res.download(filePath, fileName, (err) => {
//        if (err) {
//            console.error('File not found', err);
//            res.status(404).send('File not found');
//        }
//    });
//});

app.get('/file/:fileName', (req, res) => {
    const fileName = req.params.fileName;
    const filePath = path.join('/home/judge/webserver/nfs_shared/', fileName);

    fa.access(filePath, fa.constants.F_OK, (err) => {
        if (err) {
            console.error('File not found:', err);
            return res.status(404).send('File not found');
        }

        res.download(filePath, fileName, (err) => {
            if (err) {
                console.error('Error sending file:', err);
                return res.status(500).send('Error sending file');
            }
        });
    });
});

app.post('/upload', upload.single('file'), (req, res) => {
    if(!req.file) {
    	return res.status(400).json({ message: 'No file uploaded' });
    }
    res.json({ filename: req.file.filename, success: true });
});

app.get('/db/:name', async (req, res) => {
    const { name } = req.params;
    try {
    	const result = await pool.query('SELECT * FROM "user" WHERE name = $1', [name]);
	if (result.rows.length > 0) {
	    res.json(result.rows[0]);
	}
	else {
	    res.status(404).send('User not found');
	}
    }
    catch (err) {
        console.error(err);
	res.status(500).send('Error querying the database');
    }
});

app.listen(port, '192.168.123.1', () => {
});
