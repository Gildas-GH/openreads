package com.example.mybooks.ui.bookslist.fragments

import android.content.Context
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.core.widget.addTextChangedListener
import androidx.fragment.app.Fragment
import androidx.lifecycle.Observer
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProviders
import androidx.navigation.fragment.findNavController
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.mybooks.R
import com.example.mybooks.adapters.BookAdapter
import com.example.mybooks.data.db.BooksDatabase
import com.example.mybooks.data.db.entities.Book
import com.example.mybooks.data.repositories.BooksRepository
import com.example.mybooks.ui.bookslist.ListActivity
import com.example.mybooks.ui.bookslist.viewmodel.BooksViewModel
import com.example.mybooks.ui.bookslist.viewmodel.BooksViewModelProviderFactory
import com.example.mybooks.ui.bookslist.adder.AddBookDialog
import com.example.mybooks.ui.bookslist.adder.AddBookDialogListener
import kotlinx.android.synthetic.main.fragment_in_progress.*

class InProgressFragment : Fragment(R.layout.fragment_in_progress) {

    lateinit var viewModel: BooksViewModel

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        viewModel = (activity as ListActivity).booksViewModel

        etSearch.visibility = View.GONE
        ivClearSearch.visibility = View.GONE
        ivClearSearch.isClickable = false
        view.hideKeyboard()

        val database = BooksDatabase(view.context)
        val booksRepository = BooksRepository(database)
        val booksViewModelProviderFactory = BooksViewModelProviderFactory(booksRepository)

        viewModel = ViewModelProvider(this, booksViewModelProviderFactory).get(
            BooksViewModel::class.java)

        val factory = BooksViewModelProviderFactory(booksRepository)
        val viewModel = ViewModelProviders.of(this, factory).get(BooksViewModel::class.java)

        val bookAdapter = BookAdapter(view.context, whichFragment = "in_progress")

        rvBooks.adapter = bookAdapter
        rvBooks.layoutManager = LinearLayoutManager(view.context)

        viewModel.getInProgressBooks().observe(viewLifecycleOwner, Observer { some_books ->
            bookAdapter.differ.submitList(some_books)
        })

        fabAddBook.setOnClickListener{
            AddBookDialog(view.context,
                object: AddBookDialogListener {
                    override fun onSaveButtonClicked(item: Book) {
                        viewModel.upsert(item)
                        when(item.bookStatus) {
                            "read" -> { findNavController().navigate(
                                R.id.action_inProgressFragment_to_readFragment
                            )
                            }
                            "to_read" -> { findNavController().navigate(
                                R.id.action_inProgressFragment_to_toReadFragment
                            )
                            }
                        }
                    }
                }
            ).show()
        }

        bookAdapter.setOnBookClickListener {
            etSearch.setText("")
            val bundle = Bundle().apply {
                putSerializable("book", it)
            }
            findNavController().navigate(
                R.id.action_inProgressFragment_to_displayBookFragment,
                bundle
            )
        }

        ivSearch.setOnClickListener {
            when(etSearch.visibility) {
                View.VISIBLE -> {
                    when (etSearch.text.isEmpty()){
                        false -> {
                            viewModel.searchBooks(etSearch.text.toString()).observe(viewLifecycleOwner, Observer { some_books ->
                                bookAdapter.differ.submitList(some_books)
                            })
                        }
                    }
                }
                View.GONE -> {
                    etSearch.visibility = View.VISIBLE
                    ivClearSearch.visibility = View.VISIBLE
                    ivClearSearch.isClickable = true
                    etSearch.requestFocus()
                    it.showKeyboard()
                }
            }
        }

        etSearch.setOnKeyListener(View.OnKeyListener { v, keyCode, event ->
            if (keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_UP) {
                when (etSearch.text.isEmpty()){
                    false -> {
                        viewModel.searchBooks(etSearch.text.toString()).observe(viewLifecycleOwner, Observer { some_books ->
                            bookAdapter.differ.submitList(some_books)
                        })
                        view.hideKeyboard()
                    }
                }
                return@OnKeyListener true
            }
            false
        })

        etSearch.addTextChangedListener {
            viewModel.searchBooks(etSearch.text.toString()).observe(viewLifecycleOwner, Observer { some_books ->
                bookAdapter.differ.submitList(some_books)
            })
        }

        ivClearSearch.setOnClickListener {
            when (etSearch.text.isEmpty()) {
                false -> {
                    etSearch.setText("")
                    viewModel.searchBooks(etSearch.text.toString()).observe(viewLifecycleOwner, Observer { some_books ->
                        bookAdapter.differ.submitList(some_books)
                    })
                }
                true -> {
                    etSearch.visibility = View.GONE
                    ivClearSearch.visibility = View.GONE
                    ivClearSearch.isClickable = false
                    it.hideKeyboard()
                    viewModel.getInProgressBooks().observe(viewLifecycleOwner, Observer { some_books ->
                        bookAdapter.differ.submitList(some_books)
                    })
                }
            }
        }
    }

    fun View.hideKeyboard() {
        val inputManager = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        inputManager.hideSoftInputFromWindow(windowToken, 0)
    }

    fun View.showKeyboard() {
        val inputManager = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        inputManager.toggleSoftInputFromWindow(windowToken, 0, 0)
    }
}