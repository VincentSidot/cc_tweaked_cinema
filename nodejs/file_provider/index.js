const http = require('http')
const path = require('path')
const fs = require('fs')
const yargs = require('yargs')
const process = require('process')

// Accept command line arguments
// Command line is node index.js load [folder] (--port [port])
const options = yargs
  .scriptName('test')
  .usage('$0 <cmd> [args]')
  .option('port', {
    alias: 'p',
    description: 'port to run file provider',
    type: 'number',
  })
  .command('load [folder]', 'root folder of file provider', (yargs) => {
    yargs.positional('folder', {
      type: 'string',
      describe: 'root folder of file provider',
    })
  })
  .help().argv

function loadFile(file) {
  return new Promise((resolve, reject) => {
    // check file extension
    // if file extension is .lua then read file and return
    // if other format then return raw data
    if (file.split('.').pop() === 'lua') {
      fs.readFile(file, 'utf8', (err, data) => {
        if (err) reject(err)
        resolve(data)
      })
    } else {
      fs.readFile(file, (err, data) => {
        if (err) reject(err)
        resolve(data)
      })
    }
  })
}

function lua_print(data) {
  console.log('Lua print: ' + data)
  return 'print("' + data + '")'
}

function check_file(file) {
  // check if file is in root folder if not throw error
  for (const element of file.split('/')) {
    if (element === '..') {
      return false
    }
  }
  return true
}

function deserve_file(root) {
  // Start server and serve file
  const port = options.port || 8000 // default port is 8000
  http
    .createServer((req, res) => {
      res.writeHead(200, { 'Content-Type': 'text/plain' })
      // Get the file url path from request
      const url = req.url
      console.log('Request url: ' + url)
      if (!check_file(url)) {
        res.write(lua_print('Do not try to hack me dumbass!'))
        res.end()
        return
      }
      if (root === undefined) {
        root = '.'
      }
      const file = path.resolve(root + '/' + url)
      // Check if file is in root folder

      loadFile(file)
        .then((data) => {
          res.write(data)
          res.end()
        })
        .catch((err) => {
          console.log(err)
          res.write('File not found')
          res.end()
        })
    })
    .listen(port, () => {
      console.log(`App is running on port ${port}`)
    })
}

console.log('Deserving root folder "' + options.folder + '"')
deserve_file(options.folder)
