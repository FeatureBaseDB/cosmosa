package main

import (
	"fmt"
	"time"

	"github.com/pkg/errors"
	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"
)

func (m *Main) Read(collection *mgo.Collection) error {
	var start time.Time
	var err error
	var n int

	start = time.Now()
	n, err = collection.Find(nil).Count()
	if err != nil {
		return errors.Wrap(err, "counting all records")
	}
	fmt.Printf("%v total records: %v\n", time.Since(start), n)
	time.Sleep(5 * time.Second)

	// Find first record
	res := Person{}
	start = time.Now()
	err = collection.Find(nil).One(&res)
	if err != nil {
		return errors.Wrap(err, "finding first record")
	}
	fmt.Printf("%v to first result\n", time.Since(start))
	time.Sleep(5 * time.Second)

	// Find first intersection of 3
	start = time.Now()
	res = Person{}
	q := collection.Find(bson.M{"tiles.p1": true, "tiles.jt": true, "tiles.wy": true})
	err = q.One(&res)
	if err != nil {
		return errors.Wrap(err, "finding first segment record")
	}
	fmt.Printf("%v to first segment record\n", time.Since(start))
	time.Sleep(5 * time.Second)

	tiles := []string{"p1", "bx", "jt", "wy", "e8"}

	for _, tile := range tiles {
		start = time.Now()
		n, err = collection.Find(bson.M{"tiles." + tile: true}).Count()
		if err != nil {
			return errors.Wrap(err, "counting single tile")
		}
		fmt.Printf("%v %s count: %v\n", time.Since(start), tile, n)
		time.Sleep(5 * time.Second)
	}
	// Find count intersection of 3
	start = time.Now()
	n, err = collection.Find(bson.M{"tiles.p1": true, "tiles.jt": true, "tiles.wy": true}).Count()
	if err != nil {
		return errors.Wrap(err, "finding first segment record")
	}
	fmt.Printf("%v intersect 3 count: %v\n", time.Since(start), n)

	return nil
}
