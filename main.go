package main

import (
	"crypto/tls"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"

	"github.com/Azure/go-autorest/autorest/utils"
	"github.com/pkg/errors"
	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"
)

var (
	database string
	password string
	account  string
)

func init() {
	database = utils.GetEnvVarOrExit("COSMOSA_DB")
	password = utils.GetEnvVarOrExit("COSMOSA_DB_PASSWORD")
	account = utils.GetEnvVarOrExit("COSMOSA_ACCOUNT")
}

// Person represents a document in the collection
type Person struct {
	Id    bson.ObjectId `bson:"_id,omitempty"`
	Alive string
	Tiles map[string]bool
}

type Main struct {
	Num         int
	Insert      bool
	Concurrency int
	Query       bool
	Seed        int64
	JustCreate  bool
}

func main() {
	m := Main{}
	flag.IntVar(&m.Num, "num", 10000, "number of docs to insert")
	flag.IntVar(&m.Concurrency, "concurrency", 1, "number of goroutines doing insertion")
	flag.BoolVar(&m.Insert, "insert", false, "do insertions")
	flag.BoolVar(&m.Query, "query", false, "do queries")
	flag.Int64Var(&m.Seed, "seed", 1, "seed for rng")
	flag.BoolVar(&m.JustCreate, "just-create", false, "just create the collection and exit")
	flag.Parse()
	err := m.Run()
	if err != nil {
		log.Fatal(err)
	}
}

func (m *Main) Run() error {
	rand.Seed(m.Seed)
	// DialInfo holds options for establishing a session with a MongoDB cluster.
	dialInfo := &mgo.DialInfo{
		Addrs:    []string{fmt.Sprintf("%s.documents.azure.com:10255", account)}, // Get HOST + PORT
		Timeout:  60 * time.Second,
		Database: database, // It can be anything
		Username: account,  // Username
		Password: password, // PASSWORD
		DialServer: func(addr *mgo.ServerAddr) (net.Conn, error) {
			return tls.Dial("tcp", addr.String(), &tls.Config{})
		},
	}

	// Create a session which maintains a pool of socket connections
	// to our MongoDB.
	session, err := mgo.DialWithInfo(dialInfo)
	if err != nil {
		return errors.Errorf("Can't connect to mongo, go error %v\n", err)
	}
	log.Println("got session")

	defer session.Close()

	// SetSafe changes the session safety mode.
	// If the safe parameter is nil, the session is put in unsafe mode, and writes become fire-and-forget,
	// without error checking. The unsafe mode is faster since operations won't hold on waiting for a confirmation.
	// http://godoc.org/labix.org/v2/mgo#Session.SetMode.
	session.SetMode(mgo.Eventual, false)
	session.SetSafe(&mgo.Safe{})

	// get collection
	collection := session.DB(database).C("people")

	if m.JustCreate {
		return nil
	}

	if m.Insert {
		writes := make(chan struct{}, m.Concurrency)
		cancel := make(chan error, 1)
		wg := sync.WaitGroup{}
		start := time.Now()
		for i := 0; i < m.Concurrency; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				err := m.Write(writes, collection)
				if err != nil {
					select {
					case cancel <- err:
					}
				}
			}()
		}
		for i := 0; i < m.Num; i++ {
			select {
			case err := <-cancel:
				return errors.Wrap(err, "writing")
			case writes <- struct{}{}:
			}
		}
		close(writes)
		wg.Wait()
		log.Printf("writing %v docs took %v\n", m.Num, time.Since(start))
	}

	if m.Query {
		err := m.Read(collection)
		if err != nil {
			return errors.Wrap(err, "querying")
		}
	}
	return nil
}

func (m *Main) Write(writes chan struct{}, collection *mgo.Collection) error {
	// insert documents into collection
	for range writes {
		err := collection.Insert(GenPerson())
		if err != nil {
			return errors.Wrap(err, "inserting person")
		}
	}
	return nil
}

var letters = "abcdefghijklmnopqrstuvwxyz12345678"

func Tile() string {
	length := rand.Intn(4) + 2
	ret := make([]byte, length)
	for i := 0; i < length; i++ {
		ret[i] = letters[rand.Intn(len(letters))]
	}
	return string(ret)
}

func GenPerson() *Person {
	tiles := make(map[string]bool)
	num := rand.Intn(930) + 70
	for i := 0; i < num; i++ {
		tiles[Tile()] = true
	}
	return &Person{
		Tiles: tiles,
		Alive: "yes",
	}
}
